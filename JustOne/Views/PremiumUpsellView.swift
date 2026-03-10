//
//  PremiumUpsellView.swift
//  JustOne
//
//  Light-themed paywall presenting subscription tiers in a fixed layout.
//  Offers both Apple Pay (StoreKit) and Direct Billing purchase paths.
//

import SwiftUI
import ZeroSettleKit

struct PremiumUpsellView: View {
    @Environment(ZeroSettleManager.self) var iapManager
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.dismiss) var dismiss


    @State private var selectedTier: SubscriptionTier = .yearly
    @State private var errorMessage: String?
    @State private var webCheckoutProduct: ZSProduct?
    @State private var isLoadingWebCheckout = false
    @State private var contentHeight: CGFloat = 600
    @Environment(\.scenePhase) private var scenePhase

    private var upgradeTiers: [SubscriptionTier] {
        guard let current = iapManager.activeSubscription else {
            return SubscriptionTier.paywallTiers
        }
        return SubscriptionTier.paywallTiers.filter { $0.rank > current.rank }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            heroArea
            titleSection
            featureChecklist
            tierCards
            freeTrialBanner
            dualPriceButtons
                .padding(.vertical, 4)
            legalFooter
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.height) {
                        contentHeight = proxy.size.height
                    }
            }
        )
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .task {
            if let best = upgradeTiers.last {
                selectedTier = best
            }
            if let userId = authVM.appleUserID {
                await CheckoutSheet.warmUp(productId: selectedTier.productId, userId: userId)
            }
        }
        .onChange(of: selectedTier) { _, newTier in
            Task {
                if let userId = authVM.appleUserID {
                    await CheckoutSheet.warmUp(productId: newTier.productId, userId: userId)
                }
            }
        }
        .checkoutSheet(
            item: $webCheckoutProduct,
            userId: authVM.appleUserID ?? "",
            freeTrialDays: selectedTier.freeTrialDays,
            preload: .all,
            onPresent: { isLoadingWebCheckout = false }
        ) {
            if let product = webCheckoutProduct {
                CheckoutSheetHeader(product: product)
            }
        } onComplete: { result in
            isLoadingWebCheckout = false
            Task {
                let error = await iapManager.processWebCheckout(result, userId: authVM.appleUserID)
                if let error { errorMessage = error }
                if case .success = result { dismiss() }
            }
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { isLoadingWebCheckout = false }
        }
    }

    // MARK: - Hero Area

    private var heroArea: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(LinearGradient.premiumGradient)
            .frame(height: 100)
            .overlay(
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            )
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(iapManager.isPremium ? "Upgrade Your Plan" : "Go Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(iapManager.isPremium ? "Get more value with a longer billing cycle" : "Unlock everything")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Feature Checklist

    private var featureChecklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow("Unlimited habits")
            featureRow("Priority support")
            featureRow("Advanced analytics")
            featureRow("Cloud sync (coming soon)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.justSuccess)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Tier Cards

    /// Whether any of the visible tiers has a free trial (used to reserve consistent card height).
    private var anyTierHasTrial: Bool {
        upgradeTiers.contains { $0.freeTrialLabel != nil }
    }

    private var tierCards: some View {
        HStack(spacing: 12) {
            ForEach(upgradeTiers) { tier in
                tierCard(tier)
            }
        }
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier

        return Button { selectedTier = tier } label: {
            VStack(spacing: 8) {
                Text(tier.displayName)
                    .font(.headline)

                Text(tier.price)
                    .font(.title3.weight(.bold))

                Text(tier.pricePerMonth)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Always reserve space for the trial line when any tier has a trial
                Text(tier.freeTrialLabel ?? " ")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.justSuccess)
                    .opacity(tier.freeTrialLabel != nil ? 1 : 0)
                    .frame(height: anyTierHasTrial ? nil : 0)
                    .clipped()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.justSurface.opacity(0.85))
            )
            .overlay(alignment: .topTrailing) {
                if tier.bestValue {
                    Text("BEST VALUE")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .frame(width: 120)
                        .background(Color.justSuccess)
                        .rotationEffect(.degrees(35))
                        .offset(x: 22, y: 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.justPrimary : Color.black.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Free Trial Banner

    @ViewBuilder
    private var freeTrialBanner: some View {
        let label = selectedTier.freeTrialLabel
        HStack(spacing: 6) {
            Image(systemName: "gift.fill")
                .font(.caption)
            Text("Start your \(label ?? " ")")
                .font(.subheadline.weight(.medium))
        }
        .foregroundColor(.justSuccess)
        .opacity(label != nil ? 1 : 0)
    }

    // MARK: - Dual Price Buttons

    private var dualPriceButtons: some View {
        let zsProduct = ZeroSettle.shared.product(for: selectedTier.productId)
        return DualPriceButtons(
            storeKitPrice: zsProduct?.storeKitPrice?.formatted ?? selectedTier.price,
            webPrice: zsProduct?.webPrice?.formatted,
            savingsPercent: zsProduct?.savingsPercent,
            onStoreKit: {
                Task {
                    do {
                        let success = try await iapManager.purchaseSubscription(selectedTier, userId: authVM.appleUserID)
                        if success { dismiss() }
                    } catch where !ZeroSettleManager.isCancellation(error) {
                        errorMessage = error.localizedDescription
                    }
                }
            },
            onWeb: {
                if let zsProduct {
                    isLoadingWebCheckout = true
                    webCheckoutProduct = zsProduct
                }
            },
            isDisabled: iapManager.isPurchasing,
            isLoadingWeb: isLoadingWebCheckout
        )
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 4) {
            Button("Restore Purchases") {
                Task {
                    do {
                        try await iapManager.restorePurchases(userId: authVM.appleUserID)
                    } catch where !ZeroSettleManager.isCancellation(error) {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text("Cancel anytime \u{00B7} Powered by ZeroSettle")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
}
