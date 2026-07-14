// Vellum — the shell. Today is home; the archive is one quiet mono crumb
// away. First launch runs the onboarding sequence full-screen before
// anything else exists.

import SwiftUI

struct RootView: View {
    @AppStorage(AppKeys.onboarded) private var onboarded = false

    var body: some View {
        ZStack {
            Tokens.Surface.page.ignoresSafeArea()
            if onboarded {
                NavigationStack {
                    TodayView()
                }
                .tint(Tokens.Text.written)   // no accent color, by design
            } else {
                OnboardingView()
            }
        }
        .animation(Tokens.Motion.base, value: onboarded)
    }
}
