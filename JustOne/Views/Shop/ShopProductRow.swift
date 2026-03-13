//
//  ShopProductRow.swift
//  JustOne
//
//  Product rows for the consumable shop: subscription tiers,
//  consumable packs, and the unlimited streak saver subscription.
//

import SwiftUI
import ZeroSettleKit

// MARK: - Subscription Row

struct ShopSubscriptionRow: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {

            HStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(LinearGradient.premiumGradient)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.justPrimary.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tier.displayName)
                            .font(.headline)

                        if tier.bestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.justSuccess, in: Capsule())
                        }
                    }

                    if let trialLabel = tier.freeTrialLabel {
                        Text(trialLabel)
                            .font(.caption)
                            .foregroundColor(.justSuccess)
                    } else {
                        Text(tier.pricePerMonth)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                ShopPriceColumn(productId: tier.productId, fallbackPrice: tier.price)

                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.justPrimary)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.justPrimary.opacity(0.1) : Color.clear)
            )
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.justPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tier.displayName) plan, \(tier.price)")
    }
}

// MARK: - Consumable Row

struct ShopConsumableRow: View {
    let product: ConsumableProduct
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: "bandage.fill")
                    .font(.title2)
                    .foregroundColor(.justWarning)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.justWarning.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ShopPriceColumn(productId: product.productId, fallbackPrice: product.price)

                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.justPrimary)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.justPrimary.opacity(0.1) : Color.clear)
            )
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.justPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unlimited Streak Saver Row

struct ShopUnlimitedStreakSaverRow: View {
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: "infinity")
                    .font(.title2)
                    .foregroundColor(.justWarning)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.justWarning.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Unlimited")
                            .font(.headline)
                        Text("BEST VALUE")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.justSuccess, in: Capsule())
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    Text([StreakSaverSubscription.freeTrialLabel, "\(StreakSaverSubscription.price)/mo"].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                ShopPriceColumn(productId: StreakSaverSubscription.productId, fallbackPrice: StreakSaverSubscription.price)
                    .fixedSize()

                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.justPrimary)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.justPrimary.opacity(0.1) : Color.clear)
            )
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.justPrimary : Color.justWarning.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Price Column

struct ShopPriceColumn: View {
    let productId: String
    let fallbackPrice: String

    var body: some View {
        let zsProduct = ZeroSettle.shared.product(for: productId)

        VStack(alignment: .trailing, spacing: 3) {
            Text(zsProduct?.storeKitPrice?.formatted ?? fallbackPrice)
                .font(.subheadline.weight(.semibold))

            if let webPrice = zsProduct?.webPrice?.formatted {
                HStack(spacing: 4) {
                    Text(webPrice)
                        .font(.caption.weight(.medium))

                    if let savings = zsProduct?.savingsPercent, savings > 0 {
                        Text("-\(savings)%")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.justSuccess, in: Capsule())
                    }
                }
                .foregroundColor(.justSuccess)
            }
        }
    }
}
