//
//  ShopTypes.swift
//  JustOne
//
//  Selection model, scroll metrics, and scroll-geometry compatibility
//  helpers used by the consumable shop.
//

import SwiftUI

// MARK: - Shop Selection

enum ShopSelection: Equatable {
    case consumable(ConsumableProduct)
    case subscription(SubscriptionTier)
    case unlimitedStreakSavers

    var productId: String {
        switch self {
        case .consumable(let p): p.productId
        case .subscription(let t): t.productId
        case .unlimitedStreakSavers: StreakSaverSubscription.productId
        }
    }

    var displayName: String {
        switch self {
        case .consumable(let p): p.displayName
        case .subscription(let t): t.displayName
        case .unlimitedStreakSavers: StreakSaverSubscription.displayName
        }
    }

    var fallbackPrice: String {
        switch self {
        case .consumable(let p): p.price
        case .subscription(let t): t.price
        case .unlimitedStreakSavers: StreakSaverSubscription.price
        }
    }

    var iconName: String {
        switch self {
        case .consumable: "bandage.fill"
        case .subscription: "crown.fill"
        case .unlimitedStreakSavers: "infinity"
        }
    }

    var accentColor: Color {
        switch self {
        case .consumable: .justWarning
        case .subscription: .justPrimary
        case .unlimitedStreakSavers: .justWarning
        }
    }

    var freeTrialDays: Int {
        switch self {
        case .consumable: 0
        case .subscription(let t): t.freeTrialDays
        case .unlimitedStreakSavers: StreakSaverSubscription.freeTrialDays
        }
    }
}

// MARK: - Scroll Metrics

struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let maxOffset: CGFloat
}

// MARK: - iOS 18+ Scroll Geometry Compatibility

struct ScrollGeometryChangeModifier: ViewModifier {
    let action: (ScrollMetrics, ScrollMetrics) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ScrollMetrics.self) { geo in
                ScrollMetrics(
                    offset: geo.contentOffset.y,
                    maxOffset: geo.contentSize.height - geo.containerSize.height
                )
            } action: { old, new in
                action(old, new)
            }
        } else {
            content
        }
    }
}

extension View {
    func onScrollGeometryChangeIfAvailable(action: @escaping (ScrollMetrics, ScrollMetrics) -> Void) -> some View {
        modifier(ScrollGeometryChangeModifier(action: action))
    }
}
