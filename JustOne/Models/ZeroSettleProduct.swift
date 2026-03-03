//
//  ZeroSettleProduct.swift
//  JustOne
//
//  Product catalog for the ZeroSettle IAP mock layer.
//  Contains subscription tiers and consumable "Streak Saver" tokens.
//

import Foundation

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

    var price: String {
        switch self {
        case .weekly:  return "$1.99"
        case .monthly: return "$4.99"
        case .yearly:  return "$39.99"
        }
    }

    var pricePerWeek: String {
        switch self {
        case .weekly:  return "$1.99/wk"
        case .monthly: return "$1.15/wk"
        case .yearly:  return "$0.77/wk"
        }
    }

    var savings: String? {
        switch self {
        case .weekly:  return nil
        case .monthly: return "Save 42%"
        case .yearly:  return "Save 61%"
        }
    }

    var productId: String {
        switch self {
        case .weekly:  return "io.zerosettle.JustOne.premiumWeekly"
        case .monthly: return "io.zerosettle.justone.premiumMonthly"
        case .yearly:  return "io.zerosettle.JustOne.premiumYearly"
        }
    }

    // MARK: - Paywall & Billing Helpers

    static let paywallTiers: [SubscriptionTier] = [.weekly, .monthly, .yearly]

    var numericPrice: Double {
        switch self {
        case .weekly:  return 1.99
        case .monthly: return 4.99
        case .yearly:  return 39.99
        }
    }

    var pricePerMonth: String {
        switch self {
        case .weekly:  return String(format: "$%.2f/mo", numericPrice * (52.0 / 12.0))
        case .monthly: return "$4.99/mo"
        case .yearly:  return String(format: "$%.2f/mo", numericPrice / 12.0)
        }
    }

    var annualSavingsVsMonthly: String {
        let monthlyCostPerYear = SubscriptionTier.monthly.numericPrice * 12
        let thisCostPerYear: Double
        switch self {
        case .weekly:  thisCostPerYear = numericPrice * 52
        case .monthly: thisCostPerYear = numericPrice * 12
        case .yearly:  thisCostPerYear = numericPrice
        }
        let savings = monthlyCostPerYear - thisCostPerYear
        return String(format: "$%.2f", savings)
    }

    var directBillingPrice: String {
        String(format: "$%.2f", numericPrice * 0.80)
    }

    var bestValue: Bool { self == .yearly }

    var rank: Int {
        switch self {
        case .weekly:  return 0
        case .monthly: return 1
        case .yearly:  return 2
        }
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
