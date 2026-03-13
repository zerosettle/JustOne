//
//  SubscriptionCardView.swift
//  JustOne
//
//  Displays the user's current subscription status with upgrade,
//  change plan, and cancel options.
//

import SwiftUI
import ZeroSettleKit

struct SubscriptionCardView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Binding var showPremiumUpsell: Bool
    @Binding var showAnnualUpgrade: Bool
    @Binding var showCancelFlow: Bool
    let isUpgradeAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let tier = purchaseManager.activeSubscription {
                activeSubscriptionContent(tier: tier)
            } else {
                freeSubscriptionContent
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Active Subscription

    @ViewBuilder
    private func activeSubscriptionContent(tier: SubscriptionTier) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("JustOne Pro")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(LinearGradient.premiumGradient)
                }

                Text("Unlimited streaks")
                    .font(.subheadline)

                // Show actual price from catalog when on direct billing
                if !purchaseManager.isStoreKitBilling,
                   let product = ZeroSettle.shared.product(for: tier.productId),
                   let webPrice = product.webPrice {
                    Text("\(tier.displayName) \u{00B7} \(webPrice.formatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(tier.displayName) \u{00B7} \(tier.price)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                if purchaseManager.isSubscriptionCancelled {
                    Text("Cancelling")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                } else {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.justSuccess)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.justSuccess.opacity(0.12), in: Capsule())
                }

                if !purchaseManager.isStoreKitBilling {
                    Text("Direct billing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }

        if purchaseManager.isSubscriptionCancelled {
            if let expiresAt = purchaseManager.subscriptionExpiresAt {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text("Your subscription expires \(expiresAt, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            if purchaseManager.canUpgradeToAnnual && isUpgradeAvailable {
                Button { showAnnualUpgrade = true } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Upgrade to Annual")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(LinearGradient.premiumGradient, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            HStack {
                if !purchaseManager.isAtHighestTier {
                    Button { showPremiumUpsell = true } label: {
                        Text("Change plan")
                            .font(.subheadline)
                            .foregroundColor(.justPrimary)
                    }
                }

                Spacer()

                Button { showCancelFlow = true } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Free Plan

    private var freeSubscriptionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free Plan")
                        .font(.title3.weight(.bold))
                    Text("1 habit limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Text("Upgrade to Pro for unlimited streaks, advanced analytics, and cloud sync (coming soon).")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button { showPremiumUpsell = true } label: {
                HStack {
                    Image(systemName: "crown.fill")
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(LinearGradient.premiumGradient, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
