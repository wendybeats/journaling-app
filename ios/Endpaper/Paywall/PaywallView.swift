// The trial-expiry gate — the hard paywall, in the product's own voice.
// Appears when neither the trial window nor a subscription is live. One
// action, price plain, restore beneath; the notebook waits behind it
// (nothing is ever deleted — writing resumes the moment the subscription
// exists).

import SwiftUI

struct PaywallView: View {
    @ObservedObject private var gate = TrialGate.shared
    @State private var redeeming = false

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            Spacer()

            Text("The week is over.")
                .typeDisplay()
                .multilineTextAlignment(.center)

            Text("Your notebook is safe and waiting. Endpaper is \(priceLine) — about the price of one good paper notebook.")
                .typeWritten()
                .multilineTextAlignment(.center)

            Button {
                Task { await gate.subscribe() }   // plain yearly purchase — the week is spent
            } label: {
                Text("Keep writing")
                    .font(.custom(EndpaperFont.heading, size: 17).weight(.medium))
                    .foregroundStyle(Tokens.Text.onInverted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Space.md * 0.8)
                    .background(Tokens.Surface.inverted, in: RoundedRectangle(cornerRadius: Tokens.Radius.control))
            }
            .padding(.top, Tokens.Space.lg)

            Text("\(priceLine) · cancel anytime").typeMetaSmall()

            Button {
                Task { await gate.restore() }
            } label: {
                Text("Restore purchase").typeMetaSmall()
            }
            .padding(.top, Tokens.Space.xl)

            // Founding-member codes redeem here; the resulting transaction
            // arrives through Transaction.updates and lifts the gate.
            Button {
                redeeming = true
            } label: {
                Text("Have a code?").typeMetaSmall()
            }
            .padding(.top, Tokens.Space.sm)

            Spacer()
        }
        .padding(.horizontal, Tokens.Space.screenX + Tokens.Space.sm)
        .background(Tokens.Surface.page.ignoresSafeArea())
        .offerCodeRedemption(isPresented: $redeeming)
    }

    private var priceLine: String {
        gate.product?.displayPrice.appending(" a year") ?? "$39.99 a year"
    }
}
