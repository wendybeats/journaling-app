// The prompt choreography — the recap's call-and-response, from the
// approved card prototype: the prompt ("You asked yourself") flashes
// centered at 1.5× in full ink, holds a beat, slides up into its small
// seat on the house curve, settles to the muted meta color — and only
// then does the metric rise in. Question before answer, every time.
// Built once here so the weekly deck and the monthly sequence can't
// drift apart. Reduce Motion: everything sits at rest, no travel.

import SwiftUI

struct PromptBeat<Content: View>: View {
    let prompt: String
    /// Page-surface variant (the onboarding deck runs on the system
    /// surface, not inverted): ink flash, meta seat. Recaps keep the
    /// inverted default.
    var onPage = false
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ns
    @State private var seated = false
    @State private var revealed = false

    var body: some View {
        ZStack {
            if seated {
                VStack(spacing: 0) {
                    promptText(seated: true)
                        .matchedGeometryEffect(id: "prompt", in: ns)
                        .padding(.top, Tokens.Space.xxl)
                    Spacer()
                }
            } else {
                promptText(seated: false)
                    .matchedGeometryEffect(id: "prompt", in: ns)
                    .scaleEffect(1.5)
            }

            content()
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 16)
        }
        .task {
            if reduceMotion {
                seated = true
                revealed = true
                return
            }
            try? await Task.sleep(for: .seconds(1.0))
            withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.4)) { seated = true }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(Tokens.Motion.base) { revealed = true }
        }
    }

    private func promptText(seated: Bool) -> some View {
        Text(prompt)
            .font(.custom(EndpaperFont.meta, size: 11))
            .tracking(11 * 0.14)
            .textCase(.uppercase)
            .foregroundStyle(onPage ? (seated ? Tokens.Text.meta : Tokens.Text.written)
                                    : Tokens.Text.onInverted.opacity(seated ? 0.62 : 1))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Space.screenX)
    }
}
