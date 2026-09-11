// The glimpse dialogue (QA 2026-09-11): the number large, the pattern
// named, one line, "Noted". A compact inverted sheet — the reflections'
// surface, in miniature — never a full screen.

import SwiftUI

struct GlimpseSheet: View {
    let signal: GlimpseSignal
    var onNoted: () -> Void

    var body: some View {
        ZStack {
            Tokens.Surface.inverted.ignoresSafeArea()
            VStack(spacing: Tokens.Space.md) {
                Text(signal.mentions.formatted())
                    .font(.custom(EndpaperFont.body, size: 96).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Text.onInverted)
                Text("A pattern emerges")
                    .font(.custom(EndpaperFont.heading, size: 22).weight(.medium))
                    .foregroundStyle(Tokens.Text.onInverted)
                Text(line)
                    .font(.custom(EndpaperFont.body, size: 17))
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.sm)
                Button(action: onNoted) {
                    Text("Noted")
                        .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                        .foregroundStyle(Tokens.Surface.inverted)
                        .padding(.horizontal, Tokens.Space.xl)
                        .padding(.vertical, Tokens.Space.md * 0.8)
                        .background(Tokens.Text.onInverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                }
                .padding(.top, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
            .padding(.vertical, Tokens.Space.xl)
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Tokens.Surface.inverted)
        .presentationCornerRadius(Tokens.Radius.card * 2)
    }

    private var line: String {
        let times: String
        switch signal.mentions {
        case 1: times = "once"
        case 2: times = "twice"
        default: times = "\(signal.mentions) times"
        }
        return "You wrote \u{201C}\(signal.word)\u{201D} \(times) this week."
    }
}
