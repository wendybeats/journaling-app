// The daily reminder — local notifications only, nothing leaves the device.
// Choreography per docs/vellum-stage2-plan.md §3: off until offered, offered
// once (after two written days), the system dialog only ever follows an
// in-app yes, at most one per day, suppressed on days already written.

import Foundation
import SwiftData
import UserNotifications

enum ReminderManager {

    static let defaultHour = 8
    private static let requestID = "vellum.reminder.daily"

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
                .removePendingNotificationRequests(withIdentifiers: [requestID])
        }
    }
}
