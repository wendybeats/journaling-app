// The trial gate — StoreKit 2 scaffolding for the decided model: 7-day free
// trial, then a required paid subscription. Hard paywall, no freemium. The
// yearly product carries a 7-day introductory offer, so the trial converts
// automatically — no separate expiry paywall logic is needed once StoreKit
// is live. Price points are placeholders until the pre-submission pass.
//
// Until the app has an App Store Connect record, product loading fails in
// plain builds; the gate then falls back to the locally stamped trial date
// (the same behavior the web prototype mocks). Run with Endpaper.storekit as
// the scheme's StoreKit configuration to exercise the real purchase flow.

import Foundation
import StoreKit

@MainActor
final class TrialGate: ObservableObject {
    static let shared = TrialGate()

    static let yearlyID = "com.wendellbarton.endpaper.yearly"

    @Published private(set) var subscribed = false
    @Published private(set) var product: Product?

    private init() {
        Task { await refresh() }
        // Keep entitlement state current as transactions arrive (renewals,
        // purchases on other devices, App Store refunds).
        Task {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await refresh()
                }
            }
        }
    }

    func refresh() async {
        product = try? await Product.products(for: [Self.yearlyID]).first
        subscribed = await currentEntitlementExists()
    }

    private func currentEntitlementExists() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.yearlyID {
                return true
            }
        }
        return false
    }

    /// "Start my free week" — purchases the yearly subscription, whose
    /// introductory offer makes the first 7 days free.
    func startTrial() async {
        guard let product else {
            // No App Store record yet: stamp the trial locally, exactly as
            // the web prototype does. Replaced by the purchase above once
            // the product exists.
            UserDefaults.standard.set(
                ISO8601DateFormatter().string(from: .now),
                forKey: AppKeys.trial
            )
            return
        }
        if let result = try? await product.purchase(),
           case .success(.verified(let transaction)) = result {
            await transaction.finish()
            await refresh()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    /// The hard paywall's question. During development (no product loaded),
    /// the locally stamped week substitutes.
    var withinTrialOrSubscribed: Bool {
        if subscribed { return true }
        guard let stamp = UserDefaults.standard.string(forKey: AppKeys.trial),
              let started = ISO8601DateFormatter().date(from: stamp) else { return false }
        return Date.now.timeIntervalSince(started) < 7 * 24 * 3600
    }
}
