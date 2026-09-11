// Product analytics (decided 2026-09-11, replacing the "no analytics" rule
// with a sharper one): WE COUNT TAPS, NEVER WORDS. Anonymous product-state
// events so the funnel — onboarding → first entry → second day → glimpse
// → first weekly → offer → membership — is visible. Never journal
// content, words, names, topic words, reflection contents, exact counts,
// or ad identifiers. PostHog, EU cloud, person-less: no profile, no
// identify, no autocapture, no replay, no IDFA.
//
// The guard is structural: `Event`, `Prop` and every `Value` case are
// closed vocabularies — there is no API that accepts a free String, so
// entry text cannot be sent by accident. Add an event here, in the table
// in docs/endpaper-early-glimpse-and-analytics-brief.md, and nowhere else.

import Foundation
import PostHog

enum Analytics {
    /// PostHog project token — a public, write-only key. EU data residency.
    /// Replace with the project's token (PostHog → Settings → Project).
    static let projectToken = "phc_REPLACE_ME"
    static let host = "https://eu.i.posthog.com"

    // MARK: Vocabulary

    enum Event: String {
        case appOpened = "app_opened"                       // once per calendar day
        case onboardingCompleted = "onboarding_completed"   // once per install
        case firstEntryCreated = "first_entry_created"      // once per install
        case writingDay = "writing_day"                     // once per calendar day with ≥1 entry
        case consentAnswered = "consent_answered"
        case earlyInsightEligible = "early_insight_eligible"
        case earlyInsightOpened = "early_insight_opened"
        case earlyInsightNoted = "early_insight_noted"
        case weeklyReflectionEligible = "weekly_reflection_eligible"
        case weeklyReflectionOpened = "weekly_reflection_opened"
        case weeklyReflectionCompleted = "weekly_reflection_completed"
        case paywallViewed = "paywall_viewed"
        case subscriptionStarted = "subscription_started"
        case subscriptionRestored = "subscription_restored"
        case purchaseFailed = "purchase_failed"
        case notificationPermission = "notification_permission"
        case usageSharing = "usage_sharing"                 // the toggle itself
    }

    enum Prop: String {
        case dayIndex = "day_index"
        case wordsBucket = "words_bucket"
        case answer, locked, beats, surface, intro, granted, reason, sharing
        case weekIndex = "week_index"
    }

    enum Surface: String { case offerBeat = "offer_beat", lockedCard = "locked_card", monthlyGate = "monthly_gate", settingsSheet = "settings_sheet", settings, paywall }
    enum Answer: String { case yes, no }
    enum Reason: String { case cancelled, pending, unverified, failed, noProduct = "no_product" }
    enum Bucket: String { case under100 = "lt_100", from100 = "100_500", over500 = "500_plus" }

    /// Every value is a number, a flag, or a word from a closed list.
    enum Value {
        case int(Int), bool(Bool)
        case surface(Surface), answer(Answer), reason(Reason), bucket(Bucket)

        fileprivate var raw: Any {
            switch self {
            case .int(let v): return v
            case .bool(let v): return v
            case .surface(let v): return v.rawValue
            case .answer(let v): return v.rawValue
            case .reason(let v): return v.rawValue
            case .bucket(let v): return v.rawValue
            }
        }
    }

    static func bucket(words: Int) -> Bucket {
        words < 100 ? .under100 : (words <= 500 ? .from100 : .over500)
    }

    // MARK: Lifecycle

    private static var configured: Bool { !projectToken.hasSuffix("REPLACE_ME") }

    /// The Settings switch — default on; "no" is remembered forever.
    static var sharing: Bool { UserDefaults.standard.string(forKey: AppKeys.usage) != "no" }

    static func start() {
        guard configured else { return }
        let config = PostHogConfig(apiKey: projectToken, host: host)
        config.captureApplicationLifecycleEvents = false   // we send app_opened ourselves, daily
        config.captureScreenViews = false
        config.sessionReplay = false
        config.personProfiles = .never                     // person-less events: no profile, ever
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.optOut = !sharing
        PostHogSDK.shared.setup(config)
    }

    static func setSharing(_ on: Bool) {
        if on {
            UserDefaults.standard.set("yes", forKey: AppKeys.usage)
            guard configured else { return }
            PostHogSDK.shared.optIn()
            track(.usageSharing, [.sharing: .bool(true)])
        } else {
            track(.usageSharing, [.sharing: .bool(false)])   // the last event before silence
            UserDefaults.standard.set("no", forKey: AppKeys.usage)
            guard configured else { return }
            PostHogSDK.shared.flush()
            PostHogSDK.shared.optOut()
        }
    }

    // MARK: Capture

    static func track(_ event: Event, _ props: [Prop: Value] = [:]) {
        guard configured, sharing else { return }
        var payload = base()
        for (k, v) in props { payload[k.rawValue] = v.raw }
        PostHogSDK.shared.capture(event.rawValue, properties: payload)
    }

    /// Fires once per install (or once per `key`) — re-evaluation of the
    /// same state on every appear must not double-count a funnel step.
    static func once(_ event: Event, key: String? = nil, _ props: [Prop: Value] = [:]) {
        let stamp = "endpaper.analytics.once.\(event.rawValue)" + (key.map { ".\($0)" } ?? "")
        guard !UserDefaults.standard.bool(forKey: stamp) else { return }
        UserDefaults.standard.set(true, forKey: stamp)
        track(event, props)
    }

    /// Fires once per calendar day.
    static func daily(_ event: Event, _ props: [Prop: Value] = [:]) {
        let stamp = "endpaper.analytics.day.\(event.rawValue)"
        let today = DayFormat.key(for: .now)
        guard UserDefaults.standard.string(forKey: stamp) != today else { return }
        UserDefaults.standard.set(today, forKey: stamp)
        track(event, props)
    }

    /// The day's first commit: the install-relative day index and the
    /// day's words so far, bucketed — never the count.
    static func writingDay(dayKey: String, wordsSoFar: Int) {
        guard dayKey == DayFormat.key(for: .now) else { return }   // a stale draft isn't a writing day
        let stamp = "endpaper.analytics.day.\(Event.writingDay.rawValue)"
        guard UserDefaults.standard.string(forKey: stamp) != dayKey else { return }
        UserDefaults.standard.set(dayKey, forKey: stamp)
        track(.writingDay, [.dayIndex: .int(ReflectionCadence.daysSinceAnchor() + 1),
                            .wordsBucket: .bucket(bucket(words: wordsSoFar))])
    }

    /// Install-relative week (1 = the first week).
    static var weekIndex: Int { ReflectionCadence.daysSinceAnchor() / 7 + 1 }

    // MARK: Super properties (coarse state, on every event)

    private static func base() -> [String: Any] {
        let info = Bundle.main.infoDictionary
        let days = ReflectionCadence.daysSinceAnchor()
        let daysBucket: String
        switch days {
        case 0: daysBucket = "0"
        case 1...3: daysBucket = "1_3"
        case 4...7: daysBucket = "4_7"
        case 8...14: daysBucket = "8_14"
        default: daysBucket = "15_plus"
        }
        // TrialGate is main-actor; every caller is on main, but the seam
        // stays nonisolated so model code (EntryStore) can call it.
        let (member, unpayable): (Bool, Bool) = Thread.isMainThread
            ? MainActor.assumeIsolated { (TrialGate.shared.subscribed, TrialGate.shared.paymentsUnavailable) }
            : (false, false)
        let membership = unpayable ? "unpayable" : (member ? "member" : "none")
        let anchor = ReflectionCadence.anchor()
        let iso = Calendar(identifier: .iso8601)
        let week = String(format: "%04d-W%02d",
                          iso.component(.yearForWeekOfYear, from: anchor),
                          iso.component(.weekOfYear, from: anchor))
        return [
            "app_version": info?["CFBundleShortVersionString"] as? String ?? "",
            "build": info?["CFBundleVersion"] as? String ?? "",
            "days_since_install_bucket": daysBucket,
            "consent": ReflectionStore.shared.consent ?? "unasked",
            "membership": membership,
            "install_week": week,
        ]
    }
}
