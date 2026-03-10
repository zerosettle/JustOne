//
//  ZeroSettleProduct.swift
//  JustOne
//
//  Product catalog for the ZeroSettle IAP mock layer.
//  Contains subscription tiers and consumable "Streak Saver" tokens.
//

import Foundation
import ZeroSettleKit

// MARK: - Billing Provider

enum BillingProvider: String {
    case storeKit, direct
}

// MARK: - Subscription Tiers

enum SubscriptionTier: String, CaseIterable, Identifiable {
    case weekly, monthly, yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        }
    }

    var productId: String {
        switch self {
        case .weekly:  return "io.zerosettle.JustOne.premiumWeekly"
        case .monthly: return "io.zerosettle.justone.premiumMonthly"
        case .yearly:  return "io.zerosettle.JustOne.premiumYearly"
        }
    }

    // MARK: - SDK-Resolved Prices

    /// The ZSProduct from the SDK catalog, if available.
    private var zsProduct: ZSProduct? {
        ZeroSettle.shared.product(for: productId)
    }

    /// Display price resolved from StoreKit catalog, with hardcoded fallback.
    var price: String {
        if let formatted = zsProduct?.storeKitPrice?.formatted { return formatted }
        switch self {
        case .weekly:  return "$1.99"
        case .monthly: return "$4.99"
        case .yearly:  return "$39.99"
        }
    }

    /// Price in cents from StoreKit, with hardcoded fallback.
    var priceCents: Int {
        if let cents = zsProduct?.storeKitPrice?.amountCents { return cents }
        switch self {
        case .weekly:  return 199
        case .monthly: return 499
        case .yearly:  return 3999
        }
    }

    /// Per-month price string computed from the billing interval and actual price.
    var pricePerMonth: String {
        let cents = priceCents
        let monthly: Double
        switch self {
        case .weekly:  monthly = Double(cents) * 52.0 / 12.0 / 100.0
        case .monthly: monthly = Double(cents) / 100.0
        case .yearly:  monthly = Double(cents) / 12.0 / 100.0
        }
        return String(format: "$%.2f/mo", monthly)
    }

    // MARK: - Paywall & Billing Helpers

    static let paywallTiers: [SubscriptionTier] = [.weekly, .monthly, .yearly]

    var bestValue: Bool { self == .yearly }

    var rank: Int {
        switch self {
        case .weekly:  return 0
        case .monthly: return 1
        case .yearly:  return 2
        }
    }

    // MARK: - Free Trial

    /// Human-readable free trial label from the SDK catalog, e.g. "3-day free trial".
    /// Returns nil when no trial is configured or the user is ineligible.
    var freeTrialLabel: String? {
        zsProduct?.freeTrialLabel
    }

    /// Free trial duration in days, parsed from the SDK catalog.
    /// Returns 0 when no trial or user is ineligible.
    var freeTrialDays: Int {
        zsProduct?.freeTrialDays ?? 0
    }
}

// MARK: - Consumable Products

enum ConsumableProduct: String, CaseIterable, Identifiable {
    case streakSaver1 = "streak_saver_1"
    case streakSaver5 = "streak_saver_5"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .streakSaver1: return "1 Streak Saver"
        case .streakSaver5: return "5 Streak Savers"
        }
    }

    var description: String {
        switch self {
        case .streakSaver1: return "Fill in 1 missed day"
        case .streakSaver5: return "Fill in 5 missed days"
        }
    }

    var price: String {
        if let formatted = ZeroSettle.shared.product(for: productId)?.storeKitPrice?.formatted {
            return formatted
        }
        switch self {
        case .streakSaver1: return "$0.99"
        case .streakSaver5: return "$3.99"
        }
    }

    var tokenCount: Int {
        switch self {
        case .streakSaver1: return 1
        case .streakSaver5: return 5
        }
    }

    var productId: String {
        switch self {
        case .streakSaver1: return "io.zerosettle.JustOne.streakSaver1"
        case .streakSaver5: return "io.zerosettle.JustOne.streakSavers5"
        }
    }
}

// MARK: - Streak Saver Subscription

enum StreakSaverSubscription {
    static let productId = "io.zerosettle.justone.unlimitedStreakSavers"
    static let displayName = "Unlimited Streak Savers"
    static let description = "Never worry about missing a day again"

    private static var zsProduct: ZSProduct? {
        ZeroSettle.shared.product(for: productId)
    }

    static var price: String {
        zsProduct?.storeKitPrice?.formatted ?? "$9.99"
    }

    static var priceCents: Int {
        zsProduct?.storeKitPrice?.amountCents ?? 999
    }

    /// Human-readable free trial label from the SDK catalog, e.g. "3-day free trial".
    /// Returns nil when no trial is configured or the user is ineligible.
    static var freeTrialLabel: String? {
        zsProduct?.freeTrialLabel
    }

    /// Free trial duration in days, parsed from the SDK catalog.
    /// Returns 0 when no trial or user is ineligible.
    static var freeTrialDays: Int {
        zsProduct?.freeTrialDays ?? 0
    }
}
