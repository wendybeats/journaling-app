// The daily reminder — local notifications only, nothing leaves the device.
// Choreography per docs/endpaper-stage2-plan.md §3: off until offered, offered
// once (after two written days), the system dialog only ever follows an
// in-app yes, at most one per day, suppressed on days already written.

import Foundation
import SwiftData
import UserNotifications

enum ReminderManager {

    static let defaultHour = 8
    private static let requestID = "endpaper.reminder.daily"
    private static let editsCloseID = "endpaper.editsclose.daily"
    private static let reflectionEveID = "endpaper.reflection.eve"
    private static let reflectionDayID = "endpaper.reflection.day"

    /// Copy pool — one line, no title, no emoji, never streak language.
    /// Rotation seeded by day-of-year: deterministic, testable.
    private static let lines = [
        "The page is ready.",
        "A few lines, before the day gets loud.",
        "Nothing fancy. Just today.",
        "Yesterday had edges. Write one down.",
    ]

    // MARK: - The pre-prompt (the in-system card decides; the OS dialog obeys)

    /// The card appears only after the user has written on ≥2 distinct days
    /// and only if they've never answered. A no is remembered, never re-asked.
    static func shouldOfferPrompt(in context: ModelContext) -> Bool {
        guard UserDefaults.standard.string(forKey: AppKeys.reminder) == nil else { return false }
        return EntryStore.distinctDayCount(in: context) >= 2
    }

    static func declined() {
        UserDefaults.standard.set("no", forKey: AppKeys.reminder)
    }

    /// Only a yes opens the system dialog.
    static func accepted(in context: ModelContext) async {
        UserDefaults.standard.set("yes", forKey: AppKeys.reminder)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        if granted { await rearm(in: context) }
    }

    // MARK: - Scheduling

    /// The user-chosen reminder time (Settings), defaulting to 8:00.
    static var chosenTime: (hour: Int, minute: Int) {
        let d = UserDefaults.standard
        let hour = d.object(forKey: AppKeys.reminderHour) as? Int ?? defaultHour
        let minute = d.object(forKey: AppKeys.reminderMinute) as? Int ?? 0
        return (hour, minute)
    }

    static func setChosenTime(hour: Int, minute: Int) {
        UserDefaults.standard.set(hour, forKey: AppKeys.reminderHour)
        UserDefaults.standard.set(minute, forKey: AppKeys.reminderMinute)
    }

    /// One-shot, always re-armed. The spec's choreography ("on every entry
    /// commit and on foreground, re-arm") maps to a single non-repeating
    /// trigger aimed at the next morning that should actually fire: today's
    /// chosen time if it's still ahead and today is unwritten, otherwise
    /// tomorrow's. A repeating calendar trigger can't skip a single day;
    /// this can.
    static func rearm(in context: ModelContext) async {
        let (hour, minute) = chosenTime
        guard UserDefaults.standard.string(forKey: AppKeys.reminder) == "yes" else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])

        let cal = Calendar.current
        let todayAtHour = cal.date(bySettingHour: hour, minute: minute, second: 0, of: .now)!
        let todayWritten = EntryStore.hasEntries(forDay: DayFormat.key(), in: context)
        let fireDate = (todayAtHour > .now && !todayWritten)
            ? todayAtHour
            : cal.date(byAdding: .day, value: 1, to: todayAtHour)!

        let content = UNMutableNotificationContent()
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: fireDate) ?? 0
        content.body = lines[dayOfYear % lines.count]

        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))

        await rearmEditsClose()
        await rearmReflectionNotes()
    }

    // MARK: - The weekly reflection's two notes (QA 2026-09-05)

    /// D6 teases, D7 announces: Saturday 22:00 "arrives tomorrow",
    /// Sunday 9:00 "is here". Repeating calendar triggers, armed only
    /// while reflections consent is yes; consent changes call this with
    /// requestPermission so a reader who never enabled the daily
    /// reminder still gets the one permission ask their yes implies.
    static func rearmReflectionNotes(requestPermission: Bool = false) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reflectionEveID, reflectionDayID])
        guard ReflectionStore.shared.consent == "yes" else { return }
        if requestPermission {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let eve = UNMutableNotificationContent()
        eve.body = "Know yourself: your weekly reflection arrives tomorrow."
        var sat = DateComponents(); sat.weekday = 7; sat.hour = 22; sat.minute = 0
        try? await center.add(UNNotificationRequest(
            identifier: reflectionEveID, content: eve,
            trigger: UNCalendarNotificationTrigger(dateMatching: sat, repeats: true)))

        let day = UNMutableNotificationContent()
        day.body = "What did you say? Your weekly reflection is here."
        var sun = DateComponents(); sun.weekday = 1; sun.hour = 9; sun.minute = 0
        try? await center.add(UNNotificationRequest(
            identifier: reflectionDayID, content: day,
            trigger: UNCalendarNotificationTrigger(dateMatching: sun, repeats: true)))
    }

    // MARK: - The day's last call (11 PM)

    /// The permanence boundary is midnight; this is its one-hour warning —
    /// and the evening's quiet invitation to add a line. Rides the same
    /// opt-in as the morning reminder (no separate permission ask), with
    /// its own Settings switch. A repeating calendar trigger: every day at
    /// 23:00, no day-skipping — "anything else?" reads right whether the
    /// day is written or blank.
    static var editsCloseEnabled: Bool {
        UserDefaults.standard.object(forKey: AppKeys.editsClose) as? Bool ?? true
    }

    static func setEditsCloseEnabled(_ on: Bool) async {
        UserDefaults.standard.set(on, forKey: AppKeys.editsClose)
        await rearmEditsClose()
    }

    private static func rearmEditsClose() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [editsCloseID])
        guard UserDefaults.standard.string(forKey: AppKeys.reminder) == "yes",
              editsCloseEnabled else { return }

        let content = UNMutableNotificationContent()
        content.body = "Anything else to say from today? Edits end in 1 hour."
        var at = DateComponents(); at.hour = 23; at.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: at, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: editsCloseID, content: content, trigger: trigger))
    }

    /// Called after every commit: if today's reminder is still pending and
    /// the page now has writing, this re-aims it at tomorrow.
    static func suppressTodayIfWritten(in context: ModelContext) {
        Task { await rearm(in: context) }
    }

    // MARK: - Settings surface

    static var enabled: Bool {
        UserDefaults.standard.string(forKey: AppKeys.reminder) == "yes"
    }

    /// The Settings toggle. Turning on asks for permission if needed (a
    /// changed mind is the one sanctioned re-ask); turning off cancels the
    /// pending notification but remembers the answer.
    static func setEnabled(_ on: Bool, in context: ModelContext) async {
        UserDefaults.standard.set(on ? "yes" : "no", forKey: AppKeys.reminder)
        if on {
            await accepted(in: context)
        } else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [requestID, editsCloseID])
        }
    }
}
