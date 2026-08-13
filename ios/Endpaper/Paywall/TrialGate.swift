// The trial gate — StoreKit 2 for the decided model (rev. 2026-08-13):
// the free week is the app's own, stamped locally at onboarding with no
// purchase sheet and no card up front. When the week ends, the paywall is
// hard: one plain $39.99/year purchase. No freemium, and no introductory
// offer on the product — a user who already had their free week must not
// be offered a second one by Apple's sheet (the ASC intro offer is
// removed to match; offer codes are separate and unaffected).

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

    /// "Start my free week" — the app's own week, no purchase, no sheet.
    /// The store is not involved until the week is over.
    func startTrial() {
        UserDefaults.standard.set(
            ISO8601DateFormatter().string(from: .now),
            forKey: AppKeys.trial
        )
    }

    /// "Keep writing" — the paywall's plain yearly purchase.
    func subscribe() async {
        guard let product else { return }
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
