//
//  ZeroSettleManagerTests.swift
//  JustOneTests
//
//  Unit tests for ZeroSettleManager: token management, entitlement
//  resolution, and purchase gating logic.
//

import Testing
import Foundation
@testable import JustOne
import ZeroSettleKit

struct ZeroSettleManagerTests {

    // MARK: - Helpers

    /// Creates a fresh manager and clears persisted state so tests are isolated.
    private func makeManager() -> ZeroSettleManager {
        // Clear UserDefaults keys that ZeroSettleManager reads on init
        UserDefaults.standard.removeObject(forKey: "streakSaverTokens")
        UserDefaults.standard.removeObject(forKey: "knownEntitlementIds")
        return ZeroSettleManager()
    }

    /// Creates a mock entitlement for testing resolution logic.
    private func mockEntitlement(
        productId: String,
        source: Entitlement.Source = .storeKit,
        isActive: Bool = true
    ) -> Entitlement {
        Entitlement(
            id: UUID().uuidString,
            productId: productId,
            source: source,
            isActive: isActive,
            purchasedAt: Date()
        )
    }

    // MARK: - Initial State

    @Test func initialStateHasNoSubscription() {
        let manager = makeManager()
        #expect(manager.activeSubscription == nil)
        #expect(!manager.isPurchasing)
        #expect(manager.billingProvider == nil)
    }

    @Test func initialTokensAreZeroWhenNoPersisted() {
        let manager = makeManager()
        #expect(manager.streakSaverTokens == 0)
    }

    @Test func initialTokensReadFromUserDefaults() {
        UserDefaults.standard.set(5, forKey: "streakSaverTokens")
        let manager = ZeroSettleManager()
        #expect(manager.streakSaverTokens == 5)
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "streakSaverTokens")
    }

    // MARK: - useStreakSaver

    @Test func useStreakSaverDecrementsToken() {
        let manager = makeManager()
        manager.streakSaverTokens = 3

        let result = manager.useStreakSaver()

        #expect(result == true)
        #expect(manager.streakSaverTokens == 2)
    }

    @Test func useStreakSaverPersistsToUserDefaults() {
        let manager = makeManager()
        manager.streakSaverTokens = 2

        _ = manager.useStreakSaver()

        let persisted = UserDefaults.standard.integer(forKey: "streakSaverTokens")
        #expect(persisted == 1)
    }

    @Test func useStreakSaverFailsAtZero() {
        let manager = makeManager()
        manager.streakSaverTokens = 0

        let result = manager.useStreakSaver()

        #expect(result == false)
        #expect(manager.streakSaverTokens == 0)
    }

    @Test func useStreakSaverMultipleTimesUntilEmpty() {
        let manager = makeManager()
        manager.streakSaverTokens = 2

        #expect(manager.useStreakSaver() == true)
        #expect(manager.streakSaverTokens == 1)

        #expect(manager.useStreakSaver() == true)
        #expect(manager.streakSaverTokens == 0)

        #expect(manager.useStreakSaver() == false)
        #expect(manager.streakSaverTokens == 0)
    }

    // MARK: - resolveActiveSubscription

    @Test func resolveActiveSubscriptionReturnsNilWithNoEntitlements() {
        let result = ZeroSettleManager.resolveActiveSubscription(from: [])
        #expect(result == nil)
    }

    @Test func resolveActiveSubscriptionReturnsMatchingTier() {
        let entitlements = [mockEntitlement(productId: SubscriptionTier.monthly.productId)]
        let result = ZeroSettleManager.resolveActiveSubscription(from: entitlements)
        #expect(result == .monthly)
    }

    @Test func resolveActiveSubscriptionReturnsHighestRank() {
        let entitlements = [
            mockEntitlement(productId: SubscriptionTier.weekly.productId),
            mockEntitlement(productId: SubscriptionTier.yearly.productId),
        ]
        let result = ZeroSettleManager.resolveActiveSubscription(from: entitlements)
        #expect(result == .yearly)
    }

    @Test func resolveActiveSubscriptionIgnoresInactive() {
        let entitlements = [
            mockEntitlement(productId: SubscriptionTier.yearly.productId, isActive: false),
            mockEntitlement(productId: SubscriptionTier.weekly.productId, isActive: true),
        ]
        let result = ZeroSettleManager.resolveActiveSubscription(from: entitlements)
        #expect(result == .weekly)
    }

    @Test func resolveActiveSubscriptionForAllTiers() {
        for tier in SubscriptionTier.allCases {
            let entitlements = [mockEntitlement(productId: tier.productId)]
            let result = ZeroSettleManager.resolveActiveSubscription(from: entitlements)
            #expect(result == tier, "Should resolve \(tier)")
        }
    }

    // MARK: - resolveBillingProvider

    @Test func resolveBillingProviderStoreKit() {
        let entitlements = [mockEntitlement(productId: SubscriptionTier.monthly.productId, source: .storeKit)]
        let result = ZeroSettleManager.resolveBillingProvider(subscription: .monthly, entitlements: entitlements)
        #expect(result == .storeKit)
    }

    @Test func resolveBillingProviderDirect() {
        let entitlements = [mockEntitlement(productId: SubscriptionTier.monthly.productId, source: .webCheckout)]
        let result = ZeroSettleManager.resolveBillingProvider(subscription: .monthly, entitlements: entitlements)
        #expect(result == .direct)
    }

    @Test func resolveBillingProviderNilWhenNoSubscription() {
        let result = ZeroSettleManager.resolveBillingProvider(subscription: nil, entitlements: [])
        #expect(result == nil)
    }

    // MARK: - Business Logic (pure, no SDK dependency)

    @Test func isPremiumFalseWithNoSubscription() {
        let manager = makeManager()
        #expect(!manager.isPremium)
    }

    @Test func freeUserCanCreateFirstHabit() {
        let manager = makeManager()
        #expect(manager.canCreateHabit(currentHabitCount: 0))
    }

    @Test func freeUserCannotCreateSecondHabit() {
        let manager = makeManager()
        #expect(!manager.canCreateHabit(currentHabitCount: 1))
    }

    @Test func cannotUpgradeToAnnualWithNoSubscription() {
        let manager = makeManager()
        #expect(!manager.canUpgradeToAnnual)
    }

    @Test func isStoreKitBillingFalseWhenNil() {
        let manager = makeManager()
        #expect(!manager.isStoreKitBilling)
    }

    // MARK: - SubscriptionTier Properties

    @Test func subscriptionTierRankOrdering() {
        #expect(SubscriptionTier.weekly.rank < SubscriptionTier.monthly.rank)
        #expect(SubscriptionTier.monthly.rank < SubscriptionTier.yearly.rank)
    }

    @Test func yearlyIsBestValue() {
        #expect(SubscriptionTier.yearly.bestValue)
        #expect(!SubscriptionTier.monthly.bestValue)
        #expect(!SubscriptionTier.weekly.bestValue)
    }

    @Test func paywallTiersContainsAllTiers() {
        #expect(SubscriptionTier.paywallTiers.count == 3)
        #expect(SubscriptionTier.paywallTiers.contains(.weekly))
        #expect(SubscriptionTier.paywallTiers.contains(.monthly))
        #expect(SubscriptionTier.paywallTiers.contains(.yearly))
    }

    // MARK: - ConsumableProduct Properties

    @Test func consumableTokenCounts() {
        #expect(ConsumableProduct.streakSaver1.tokenCount == 1)
        #expect(ConsumableProduct.streakSaver5.tokenCount == 5)
    }

    @Test func consumableProductIds() {
        #expect(ConsumableProduct.streakSaver1.productId == "io.zerosettle.JustOne.streakSaver1")
        #expect(ConsumableProduct.streakSaver5.productId == "io.zerosettle.JustOne.streakSavers5")
    }
}
