// The trial gate — StoreKit 2 for the decided model (rev. 2026-08-13b,
// upfront conversion): onboarding purchases the yearly subscription on
// day one; the ASC introductory offer makes the first week free and the
// trial converts automatically unless cancelled. Onboarding proceeds
// ONLY when the purchase verifies — dismissing the sheet must not grant
// a shadow week (that was the double-free-week bug: local stamp, then
// Apple's trial again at the paywall). The local stamp survives solely
// as the offline-first-run fallback; the paywall then runs the real
// purchase, where Apple decides intro-offer eligibility per account.

import Foundation
import StoreKit

@MainActor
final class TrialGate: ObservableObject {
    static let shared = TrialGate()

    static let yearlyID = "com.wendellbarton.endpaper.yearly"

    @Published private(set) var subscribed = false
    @Published private(set) var product: Product?

    /// Storefronts where Apple itself processes no payments — no paid
    /// apps, no in-app purchase, no subscriptions, and no offer-code
    /// redemption. Russia since March 2022. A paywall there can only ever
    /// be a locked door: nobody can pay through it, and refusing access
    /// forfeits the whole audience for revenue that cannot exist. So
    /// Endpaper stays open instead (decided 2026-08-21). If Apple
    /// restores payments, or the reader moves to a storefront that can
    /// transact, the flag clears on the next refresh and the normal gate
    /// applies — no grandfathering, no special case to unwind.
    static let unpayableStorefronts: Set<String> = ["RUS"]

    /// Cached so the very first frame after launch is already correct —
    /// the storefront lookup is async, and a paywall must never flash in
    /// front of someone who has no way to dismiss it.
    @Published private(set) var paymentsUnavailable =
        UserDefaults.standard.bool(forKey: AppKeys.paymentsUnavailable)

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
        if let code = await Storefront.current?.countryCode {
            let unpayable = Self.unpayableStorefronts.contains(code)
            paymentsUnavailable = unpayable
            UserDefaults.standard.set(unpayable, forKey: AppKeys.paymentsUnavailable)
        }
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

    /// "Start my free week" — purchases the yearly subscription; the
    /// introductory offer makes the first week free and it converts
    /// automatically. Returns whether the gate actually opened — a
    /// dismissed sheet returns false and onboarding stays put.
    func startTrial() async -> Bool {
        if product == nil { await refresh() }
        // Nothing to purchase where Apple takes no payments — onboarding
        // proceeds and the gate stays open for good.
        if paymentsUnavailable { return true }
        guard let product else {
            // Store unreachable (offline first run): the app's own week,
            // so onboarding can't brick. The paywall at its end runs the
            // real purchase.
            Self.stampTrialStart()
            return true
        }
        if let result = try? await product.purchase(),
           case .success(.verified(let transaction)) = result {
            await transaction.finish()
            await refresh()
            return true
        }
        return false
    }

    /// "Keep writing" — the paywall's purchase for lapsed/offline-onboarded
    /// users. Apple applies the intro offer only if this account never
    /// used it, so nobody is promised a second free week.
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
        if subscribed || paymentsUnavailable { return true }
        guard let started = Self.trialStart() else { return false }
        return Date.now.timeIntervalSince(started) < 7 * 24 * 3600
    }

    /// The free-model question (1.0.4): writing is never gated; this gates
    /// reflections beyond the first free weekly. Unpayable storefronts get
    /// everything — a membership nobody can buy would just be a locked door.
    var reflectionsUnlocked: Bool {
        subscribed || paymentsUnavailable
    }

    // MARK: - The local trial stamp
    //
    // The stamp is mirrored into iCloud key-value storage, not kept in
    // UserDefaults alone. Deleting the app wipes UserDefaults but not the
    // iCloud store, so a delete-and-reinstall can't mint a second free
    // week on the same Apple ID while iCloud keeps the notebook intact
    // (raised 2026-08-22). Apple's own introductory offer is already
    // per-Apple-ID and unrepeatable; this closes the same door on the
    // offline fallback beside it. A different Apple ID is a different
    // person as far as we're concerned — and signing out of iCloud to
    // farm weeks costs the abuser the synced notebook they wanted to keep.

    private static let cloudStore = NSUbiquitousKeyValueStore.default

    /// The earliest stamp either store knows about — a reinstall reads
    /// the cloud's older date rather than starting the clock again.
    static func trialStart() -> Date? {
        let f = ISO8601DateFormatter()
        let local = UserDefaults.standard.string(forKey: AppKeys.trial).flatMap(f.date(from:))
        let cloud = cloudStore.string(forKey: AppKeys.trial).flatMap(f.date(from:))
        switch (local, cloud) {
        case let (l?, c?): return min(l, c)
        case let (l?, nil): return l
        case let (nil, c?): return c
        default: return nil
        }
    }

    /// Start the clock once and never restart it.
    static func stampTrialStart() {
        guard trialStart() == nil else { return }
        let stamp = ISO8601DateFormatter().string(from: .now)
        UserDefaults.standard.set(stamp, forKey: AppKeys.trial)
        cloudStore.set(stamp, forKey: AppKeys.trial)
        cloudStore.synchronize()
    }
}
