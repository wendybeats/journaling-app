// Endpaper — the shell. Today is home; the archive is one quiet mono crumb
// away. First launch runs the onboarding sequence full-screen before
// anything else exists.
//
// Free model (1.0.4): there is no app-level paywall any more — writing is
// free forever, and the membership gates reflections (see TrialGate.
// reflectionsUnlocked and the weekly deck's offer beat). PaywallView is
// retired from this shell.

import SwiftUI

struct RootView: View {
    @AppStorage(AppKeys.onboarded) private var onboarded = false
    @AppStorage(AppKeys.faceLock) private var faceLock = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var locked = false
    @State private var arriving = false

    var body: some View {
        ZStack {
            Tokens.Surface.page.ignoresSafeArea()
            if !onboarded {
                OnboardingView()
            } else if locked {
                // Privacy outranks everything: the lock sits above the day.
                LockView { locked = false }
            } else {
                NavigationStack {
                    TodayView()
                }
                .tint(Tokens.Text.written)   // no accent color, by design

                // First open of the day: the countdown, then the dot dive.
                if arriving {
                    DailyArrival {
                        withAnimation(Tokens.Motion.base) { arriving = false }
                    }
                }
            }
        }
        .animation(Tokens.Motion.base, value: onboarded)
        .onAppear {
            locked = faceLock && onboarded
            armArrival()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && faceLock { locked = true }
            if phase == .active { armArrival() }
        }
        .onChange(of: onboarded) { _, done in
            // The install day: seeds the ghost-prompt week and keeps the
            // first session splash-free — day one's arrival is the deck.
            if done { armFirstDay() }
        }
    }

    /// Play the arrival once per calendar day — but never on the day the
    /// user onboards (two splashes in a minute), and never over the lock.
    private func armArrival() {
        guard onboarded, !locked, !arriving else { return }
        if UserDefaults.standard.string(forKey: AppKeys.firstDay) == nil {
            armFirstDay()   // first open ever (or an upgrade): stamp, no splash
            return
        }
        guard DailyArrival.due else { return }
        DailyArrival.markPlayed()
        arriving = true
    }

    private func armFirstDay() {
        let today = DayFormat.key(for: .now)
        if UserDefaults.standard.string(forKey: AppKeys.firstDay) == nil {
            UserDefaults.standard.set(today, forKey: AppKeys.firstDay)
            DailyArrival.markPlayed()   // no splash on top of onboarding's own
        }
    }
}
