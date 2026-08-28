// The first-open-of-day moment (1.0.4): the countdown line held large,
// then the day's dot expanding until its ink fills the screen, fading
// into Today. Same dive motif as onboarding's splash and the calendar —
// and it does the retention work: every open names when the next
// reflection arrives, so the week always has a destination.
// Plays once per calendar day; Reduce Motion skips it entirely.

import SwiftUI

struct DailyArrival: View {
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filling = false
    @State private var faded = false

    var body: some View {
        ZStack {
            Tokens.Surface.page

            VStack(spacing: Tokens.Space.xl) {
                Text(Self.line())
                    .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                    .foregroundStyle(Tokens.Text.heading)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.screenX)
                    .opacity(filling ? 0 : 1)

                Circle()
                    .fill(Tokens.Dot.filled)
                    .frame(width: 12, height: 12)
                    .scaleEffect(filling ? 280 : 1)
            }
        }
        .ignoresSafeArea()
        .opacity(faded ? 0 : 1)
        .task {
            if reduceMotion {
                onDone()
                return
            }
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.55)) { filling = true }
            try? await Task.sleep(for: .seconds(0.62))
            withAnimation(Tokens.Motion.base) { faded = true }
            try? await Task.sleep(for: .seconds(Tokens.Motion.baseDuration))
            onDone()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.line())
    }

    /// The countdown, or the bare weekday for readers who said no to
    /// reflections — the moment still belongs to the day, never to a pitch.
    static func line(now: Date = .now) -> String {
        guard ReflectionStore.shared.consent != "no" else {
            return DayFormat.weekdayName(now) + "."
        }
        switch Reflect.daysUntilReflection(now: now) {
        case 0: return "Your reflection\nis ready."
        case 1: return "Your reflection\narrives tomorrow."
        case let n: return "Your reflection\nis \(n) days away."
        }
    }

    /// Once per calendar day, and only after onboarding.
    static var due: Bool {
        UserDefaults.standard.string(forKey: AppKeys.lastArrival) != DayFormat.key(for: .now)
    }

    static func markPlayed() {
        UserDefaults.standard.set(DayFormat.key(for: .now), forKey: AppKeys.lastArrival)
    }
}
