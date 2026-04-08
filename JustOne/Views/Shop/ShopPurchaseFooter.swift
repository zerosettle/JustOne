//
//  ShopPurchaseFooter.swift
//  JustOne
//
//  Morphing purchase footer that collapses/expands on scroll,
//  showing App Store and Pay Direct purchase buttons.
//

import SwiftUI
import ZeroSettleKit

struct ShopPurchaseFooter: View {
    let selection: ShopSelection?
    @Binding var isFooterExpanded: Bool
    @Binding var webCheckoutProduct: ZSProduct?
    @Binding var isLoadingWebCheckout: Bool
    @Binding var errorMessage: String?
    @Environment(PurchaseManager.self) private var purchaseManager
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        if let selection {
            let zsProduct = ZeroSettle.shared.product(for: selection.productId)

            VStack(spacing: isFooterExpanded ? 10 : 0) {
                HStack(spacing: 8) {
                    Image(systemName: selection.iconName)
                        .font(.system(size: 13))
                        .foregroundColor(selection.accentColor)
                        .frame(width: isFooterExpanded ? 0 : nil)
                        .opacity(isFooterExpanded ? 0 : 1)
                        .clipped()

                    Text(selection.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isFooterExpanded ? .secondary : .primary)
                        .lineLimit(1)
                }

                footerButtons(selection: selection, zsProduct: zsProduct)
                    .frame(height: isFooterExpanded ? nil : 0, alignment: .top)
                    .frame(maxWidth: isFooterExpanded ? .infinity : 0)
                    .clipped()
                    .opacity(isFooterExpanded ? 1 : 0)
                    .allowsHitTesting(isFooterExpanded)
            }
            .padding(.horizontal, isFooterExpanded ? 16 : 12)
            .padding(.top, isFooterExpanded ? 14 : 9)
            .padding(.bottom, isFooterExpanded ? 24 : 9)
            .frame(maxWidth: isFooterExpanded ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: isFooterExpanded ? 28 : 22, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: isFooterExpanded ? 28 : 22, style: .continuous)
                            .fill(Color.justPrimary.opacity(0.25))
                    }
            }
            .shadow(color: Color.justPrimary.opacity(0.2), radius: 20, y: 0)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .padding(.horizontal, isFooterExpanded ? 12 : 0)
            .padding(.bottom, 16)
            .overlay {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isFooterExpanded = true
                        }
                    }
                    .allowsHitTesting(!isFooterExpanded)
            }
        }
    }

    private func footerButtons(selection: ShopSelection, zsProduct: ZSProduct?) -> some View {
        HStack(spacing: 10) {
            // App Store button
            Button {
                ZeroSettle.trackEvent(.checkoutStarted, productId: selection.productId, screenName: "ConsumableShopView", metadata: ["path": "storekit"])
                Task {
                    do {
                        switch selection {
                        case .consumable(let product):
                            _ = try await purchaseManager.purchaseConsumable(product, userId: authViewModel.appleUserID)
                        case .subscription(let tier):
                            _ = try await purchaseManager.purchaseSubscription(tier, userId: authViewModel.appleUserID)
                        case .unlimitedStreakSavers:
                            _ = try await purchaseManager.purchaseStreakSaverSubscription(userId: authViewModel.appleUserID)
                        }
                    } catch where !ZeroSettleError.isCancellation(error) {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        if purchaseManager.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "applelogo")
                                .font(.subheadline)
                        }
                        Text("App Store")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text(zsProduct?.storeKitPrice?.formatted ?? selection.fallbackPrice)
                        .font(.caption)
                        .fontWeight(.medium)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.systemGray3))
                )
                .opacity(purchaseManager.isPurchasing ? 0.5 : 1.0)
            }
            .disabled(purchaseManager.isPurchasing)
            .accessibilityLabel("Buy via App Store, \(zsProduct?.storeKitPrice?.formatted ?? selection.fallbackPrice)")

            // Pay Direct button (only when web price exists and web checkout is enabled)
            if let webPrice = zsProduct?.webPrice?.formatted, ZeroSettle.shared.isWebCheckoutEnabled {
                Button {
                    ZeroSettle.trackEvent(.checkoutStarted, productId: selection.productId, screenName: "ConsumableShopView", metadata: ["path": "web"])
                    if let zsProduct {
                        isLoadingWebCheckout = true
                        webCheckoutProduct = zsProduct
                    }
                } label: {
                    VStack(spacing: 4) {
                        if isLoadingWebCheckout {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "creditcard.fill")
                                    .font(.subheadline)
                                Text("Pay Direct")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            HStack(spacing: 6) {
                                Text(webPrice)
                                    .font(.caption)
                                    .fontWeight(.medium)

                                if let savings = zsProduct?.savingsPercent, savings > 0 {
                                    Text("Save \(savings)%")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(
                                            Capsule()
                                                .fill(.white.opacity(0.25))
                                        )
                                }
                            }
                            .opacity(0.9)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.68, blue: 0.38),
                                        Color(red: 0.10, green: 0.55, blue: 0.45)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .opacity(purchaseManager.isPurchasing || isLoadingWebCheckout ? 0.7 : 1.0)
                }
                .disabled(purchaseManager.isPurchasing || isLoadingWebCheckout)
                .accessibilityLabel({
                    var label = "Buy direct, \(zsProduct?.webPrice?.formatted ?? selection.fallbackPrice)"
                    if let savings = zsProduct?.savingsPercent, savings > 0 {
                        label += ", save \(savings) percent"
                    }
                    return label
                }())
            }
        }
    }
}
