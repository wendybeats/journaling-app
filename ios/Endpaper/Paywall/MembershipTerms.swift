// The subscription disclosure App Review requires on every purchase
// surface (Guideline 3.1.2(c), 2026-09-14): title, length, price, and
// working links to the privacy policy and Terms of Use. One view, in the
// meta register, so every offer carries the same four facts.

import SwiftUI

struct MembershipTerms: View {
    /// Inverted surfaces (the offer beat, the sheets) vs the page (Settings).
    var onInverted = true
    @ObservedObject private var gate = TrialGate.shared

    static let privacyURL = URL(string: "https://endpaper.space/privacy.html")!
    static let termsURL = URL(string: "https://endpaper.space/terms.html")!

    private var ink: Color { onInverted ? Tokens.Text.onInverted : Tokens.Text.written }
    private var dim: Color { onInverted ? Tokens.Text.onInverted.opacity(0.55) : Tokens.Text.meta }

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            Text("Endpaper Membership · 1 year · \(gate.product?.displayPrice ?? "$39.99") per year after a 7-day free trial")
                .font(.custom(EndpaperFont.meta, size: 9))
                .tracking(9 * 0.1)
                .textCase(.uppercase)
                .foregroundStyle(dim)
                .multilineTextAlignment(.center)
            Text("Auto-renews until cancelled in Settings → Apple ID → Subscriptions")
                .font(.custom(EndpaperFont.meta, size: 9))
                .tracking(9 * 0.1)
                .textCase(.uppercase)
                .foregroundStyle(dim)
                .multilineTextAlignment(.center)
            HStack(spacing: Tokens.Space.md) {
                Link(destination: Self.privacyURL) {
                    Text("Privacy Policy").font(.custom(EndpaperFont.meta, size: 10)).tracking(10 * 0.14)
                        .textCase(.uppercase).underline().foregroundStyle(ink.opacity(0.8))
                }
                Link(destination: Self.termsURL) {
                    Text("Terms of Use").font(.custom(EndpaperFont.meta, size: 10)).tracking(10 * 0.14)
                        .textCase(.uppercase).underline().foregroundStyle(ink.opacity(0.8))
                }
            }
            .padding(.top, 2)
        }
        .padding(.top, Tokens.Space.md)
    }
}
