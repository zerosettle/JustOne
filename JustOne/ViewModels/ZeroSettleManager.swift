//
//  ZeroSettleManager.swift
//  JustOne
//
//  App-level IAP manager. Delegates product loading, purchases,
//  and entitlement tracking to the ZeroSettleKit SDK. Manages
//  app-specific state (streak saver tokens, purchasing flag).
//

import SwiftUI
import StoreKit
import OSLog
import ZeroSettleKit

// MARK: - Manager

@Observable
class ZeroSettleManager {

    // MARK: - Stored State

    var streakSaverTokens: Int = 0
    var isPurchasing = false

    // MARK: - Persistence

    private static let streakSaverTokensKey = "streakSaverTokens"
    private static let knownEntitlementIdsKey = "knownEntitlementIds"

    private func persistTokens() {
        UserDefaults.standard.set(streakSaverTokens, forKey: Self.streakSaverTokensKey)
    }

    // MARK: - Init

    init() {
        streakSaverTokens = UserDefaults.standard.integer(forKey: Self.streakSaverTokensKey)
    }

    // MARK: - Computed Entitlement State

    /// The highest-rank active subscription tier, derived from SDK entitlements.
    var activeSubscription: SubscriptionTier? {
        Self.resolveActiveSubscription(from: ZeroSettle.shared.entitlements)
    }

    /// How the active subscription is billed, derived from SDK entitlements.
    var billingProvider: BillingProvider? {
        Self.resolveBillingProvider(
            subscription: activeSubscription,
            entitlements: ZeroSettle.shared.activeEntitlements
        )
    }

    var isPremium: Bool { activeSubscription != nil }

    var isStoreKitBilling: Bool { billingProvider == .storeKit }

    var isAtHighestTier: Bool { activeSubscription == .yearly }

    var canUpgradeToAnnual: Bool {
        guard let tier = activeSubscription else { return false }
        return tier == .weekly || tier == .monthly
    }

    func canCreateHabit(currentHabitCount: Int) -> Bool {
        isPremium || currentHabitCount < 1
    }

    // MARK: - Resolution Logic (internal for testability)

    /// Returns the highest-rank active subscription tier from the given entitlements.
    static func resolveActiveSubscription(from entitlements: [Entitlement]) -> SubscriptionTier? {
        for tier in SubscriptionTier.allCases.sorted(by: { $0.rank > $1.rank }) {
            if entitlements.contains(where: { $0.productId == tier.productId && $0.isActive }) {
                return tier
            }
        }
        return nil
    }

    /// Returns the billing provider for the given subscription and entitlements.
    /// Prefers StoreKit when entitlements from both sources exist (e.g. user
    /// switched from direct billing back to the App Store).
    static func resolveBillingProvider(
        subscription: SubscriptionTier?,
        entitlements: [Entitlement]
    ) -> BillingProvider? {
        guard let tier = subscription else { return nil }
        let matching = entitlements.filter { $0.productId == tier.productId }
        guard !matching.isEmpty else { return nil }
        if matching.contains(where: { $0.source == .storeKit }) { return .storeKit }
        return .direct
    }

    // MARK: - Purchase Flows

    func purchaseSubscription(_ tier: SubscriptionTier, userId: String?) async throws -> Bool {
        try await purchase(productId: tier.productId, userId: userId)
    }

    func purchaseConsumable(_ product: ConsumableProduct, userId: String? = nil) async throws -> Bool {
        let success = try await purchase(productId: product.productId, userId: userId)
        if success {
            streakSaverTokens += product.tokenCount
            persistTokens()
        }
        return success
    }

    func useStreakSaver() -> Bool {
        guard streakSaverTokens > 0 else { return false }
        streakSaverTokens -= 1
        persistTokens()
        return true
    }

    /// Calls the SDK's ``restoreEntitlements`` to get a unified view of all
    /// purchases (StoreKit + web checkout) and credits tokens for any
    /// web-checkout consumable entitlements not yet processed.
    func syncWithSDK(userId: String) async {
        do {
            let entitlements = try await ZeroSettle.shared.restoreEntitlements(userId: userId)

            // --- Consumables (web-checkout only) ---
            var knownIds = Set(
                UserDefaults.standard.stringArray(forKey: Self.knownEntitlementIdsKey) ?? []
            )
            var didCreditTokens = false

            for entitlement in entitlements where entitlement.source == .webCheckout {
                guard !knownIds.contains(entitlement.id) else { continue }
                if let product = ConsumableProduct.allCases.first(where: { $0.productId == entitlement.productId }) {
                    streakSaverTokens += product.tokenCount
                    didCreditTokens = true
                }
                knownIds.insert(entitlement.id)
            }

            UserDefaults.standard.set(Array(knownIds), forKey: Self.knownEntitlementIdsKey)
            if didCreditTokens { persistTokens() }

            logSwitchAndSaveEligibility()

        } catch {
            AppLogger.iap.error("Failed to restore entitlements: \(error)")
        }
    }

    private func logSwitchAndSaveEligibility() {
        let premium = isPremium
        let storeKit = isStoreKitBilling
        let tierName = activeSubscription?.displayName ?? "none"
        let billingName = billingProvider == .storeKit ? "storeKit" : billingProvider == .direct ? "direct" : "none"
        let migrationState = ZeroSettle.shared.migrationManager.map { String(describing: $0.state) } ?? "nil"
        let hasOffer = ZeroSettle.shared.migrationManager?.offerData != nil

        let entitlementSummary = ZeroSettle.shared.activeEntitlements.map {
            "[\($0.productId) source=\($0.source) id=\($0.id)]"
        }.joined(separator: ", ")

        AppLogger.iap.info("""
            [Switch & Save] isPremium=\(premium), \
            tier=\(tierName), \
            billing=\(billingName), \
            migrationState=\(migrationState), \
            hasOffer=\(hasOffer), \
            bannerEligible=\(premium && storeKit), \
            entitlements=[\(entitlementSummary)]
            """)
    }

    /// Handles a web checkout result: syncs entitlements on success,
    /// ignores cancellations, and returns an error message if one occurred.
    func processWebCheckout<T>(_ result: Result<T, Error>, userId: String?) async -> String? {
        switch result {
        case .success:
            if let userId { await syncWithSDK(userId: userId) }
            return nil
        case .failure(let error):
            if let zsError = error as? ZeroSettleError, case .cancelled = zsError { return nil }
            return error.localizedDescription
        }
    }

    func restorePurchases(userId: String? = nil) async throws {
        try await AppStore.sync()
        if let userId {
            await syncWithSDK(userId: userId)
        }
    }

    // MARK: - Private — Purchase

    private func purchase(productId: String, userId: String? = nil) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            _ = try await ZeroSettle.shared.purchaseViaStoreKit(productId: productId, userId: userId)
            return true
        } catch let error as ZeroSettleError {
            switch error {
            case .cancelled, .purchasePending: return false
            default: throw error
            }
        }
    }
}
