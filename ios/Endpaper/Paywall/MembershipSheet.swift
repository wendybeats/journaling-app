// The membership offer as its own surface (QA 2026-09-05): presented
// when a non-member turns Reflections on in Settings. Deliberately the
// OPPOSITE surface — the inverted world every reflection lives in — so
// the sheet shows what's being bought. Consent itself is never gated:
// dismissing keeps reflections on and the first weekly stays free.

import SwiftUI

struct MembershipSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var gate = TrialGate.shared

    var body: some View {
        ZStack {
            Tokens.Surface.inverted.ignoresSafeArea()
            VStack(spacing: Tokens.Space.lg) {
                Spacer()
                Text("Reflections")
                    .font(.custom(EndpaperFont.meta, size: 11))
                    .tracking(11 * 0.14)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.62))
                Text("Every week.\nEvery month.\nA year you can hold.")
                    .font(.custom(EndpaperFont.heading, size: 34).weight(.semibold))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .multilineTextAlignment(.center)
                Text("Your writing, read back to you — no analysis, no AI. Writing stays free, forever.")
                    .font(.custom(EndpaperFont.body, size: 17))
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button {
                    Task {
                        await TrialGate.shared.subscribe()
                        if TrialGate.shared.reflectionsUnlocked { dismiss() }
                    }
                } label: {
                    Text("Join — \(gate.product?.displayPrice ?? "$39.99") a year, first week free")
                        .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                        .foregroundStyle(Tokens.Surface.inverted)
                        .padding(.horizontal, Tokens.Space.xl)
                        .padding(.vertical, Tokens.Space.md * 0.8)
                        .background(Tokens.Text.onInverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
                }
                .padding(.top, Tokens.Space.sm)
                Button { dismiss() } label: {
                    Text("Not now")
                        .font(.custom(EndpaperFont.meta, size: 11))
                        .tracking(11 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.55))
                }
                Spacer()
                Button {
                    Task {
                        await TrialGate.shared.restore()
                        if TrialGate.shared.reflectionsUnlocked { dismiss() }
                    }
                } label: {
                    Text("Restore purchase")
                        .font(.custom(EndpaperFont.meta, size: 10))
                        .tracking(10 * 0.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Text.onInverted.opacity(0.4))
                }
                .padding(.bottom, Tokens.Space.lg)
            }
            .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
        }
    }
}
