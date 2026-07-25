// Endpaper — the shell. Today is home; the archive is one quiet mono crumb
// away. First launch runs the onboarding sequence full-screen before
// anything else exists.

import SwiftUI

struct RootView: View {
    @AppStorage(AppKeys.onboarded) private var onboarded = false
    @AppStorage(AppKeys.faceLock) private var faceLock = false
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var gate = TrialGate.shared
    @State private var locked = false

    var body: some View {
        ZStack {
            Tokens.Surface.page.ignoresSafeArea()
            if !onboarded {
                OnboardingView()
            } else if locked {
                // Privacy outranks commerce: the lock sits above everything.
                LockView { locked = false }
            } else if !gate.withinTrialOrSubscribed {
                // The hard paywall: trial over, no subscription. The
                // notebook waits untouched behind it.
                PaywallView()
            } else {
                NavigationStack {
                    TodayView()
                }
                .tint(Tokens.Text.written)   // no accent color, by design
            }
        }
        .animation(Tokens.Motion.base, value: onboarded)
        .onAppear { locked = faceLock && onboarded }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && faceLock { locked = true }
        }
    }
}
