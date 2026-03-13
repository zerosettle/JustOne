//
//  ConsumableShopView.swift
//  JustOne
//
//  Shop sheet for purchasing Pro subscriptions and
//  "Streak Saver" consumable tokens via ZeroSettle.
//

import SwiftUI
import ZeroSettleKit

struct ConsumableShopView: View {
    @Environment(PurchaseManager.self) var purchaseManager
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(\.dismiss) var dismiss

    @State private var errorMessage: String?
    @State private var webCheckoutProduct: ZSProduct?
    @State private var isLoadingWebCheckout = false
    @State private var selection: ShopSelection? = .consumable(.streakSaver1)

    @State private var isFooterExpanded = true
    @State private var scrollAccumulator: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient.justBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        streakSaverSection

                        if !purchaseManager.isPremium {
                            subscriptionSection
                        }

                        Color.clear.frame(height: 120)
                    }
                    .padding(.top, 20)
                }
                .onScrollGeometryChangeIfAvailable { old, new in
                    handleScroll(from: old, to: new)
                }

                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, Color(.systemBackground).opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea(edges: .bottom)

                ShopPurchaseFooter(
                    selection: selection,
                    isFooterExpanded: $isFooterExpanded,
                    webCheckoutProduct: $webCheckoutProduct,
                    isLoadingWebCheckout: $isLoadingWebCheckout,
                    errorMessage: $errorMessage
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isFooterExpanded)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // SDK PATTERN: .checkoutSheet with onPresent callback clears loading state.
            // Each view has its own .checkoutSheet because freeTrialDays and
            // onComplete handlers differ per context.
            .checkoutSheet(
                item: $webCheckoutProduct,
                userId: authViewModel.appleUserID ?? "",
                freeTrialDays: selection?.freeTrialDays ?? 0,
                preload: .all,
                onPresent: { isLoadingWebCheckout = false }
            ) {
                if let product = webCheckoutProduct {
                    CheckoutSheetHeader(product: product)
                }
            } onComplete: { result in
                isLoadingWebCheckout = false
                Task {
                    let error = await purchaseManager.processWebCheckout(result, userId: authViewModel.appleUserID)
                    if let error { errorMessage = error }
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
            .onAppear {
                ZeroSettle.trackEvent(.paywallViewed, productId: selection?.productId ?? "", screenName: "ConsumableShopView")
            }
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient.premiumGradient)

                Text("Pro Subscription")
                    .font(.title2.weight(.bold))

                Text("Unlock unlimited habits, advanced analytics,\ncustom themes, and cloud sync (coming soon).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(SubscriptionTier.paywallTiers) { tier in
                    ShopSubscriptionRow(
                        tier: tier,
                        isSelected: selection == .subscription(tier)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = .subscription(tier)
                            isFooterExpanded = true
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Streak Saver Section

    private var streakSaverSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                Image(systemName: "bandage.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.justWarning)

                Text("Streak Savers")
                    .font(.title2.weight(.bold))

                Text("Missed a day? No problem.\nUse a streak saver to fill in a missed day\nand keep your progress intact.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.justWarning)
                Text("Your Balance:")
                    .foregroundColor(.secondary)
                if purchaseManager.hasUnlimitedStreakSavers {
                    HStack(spacing: 4) {
                        Image(systemName: "infinity")
                        Text("Unlimited")
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.justSuccess)
                } else {
                    Text("\(purchaseManager.streakSaverTokens) tokens")
                        .fontWeight(.bold)
                }
            }

            VStack(spacing: 12) {
                if !purchaseManager.hasUnlimitedStreakSavers {
                    ShopUnlimitedStreakSaverRow(
                        isSelected: selection == .unlimitedStreakSavers
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = .unlimitedStreakSavers
                            isFooterExpanded = true
                        }
                    }
                }

                ForEach(ConsumableProduct.allCases) { product in
                    ShopConsumableRow(
                        product: product,
                        isSelected: selection == .consumable(product)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = .consumable(product)
                            isFooterExpanded = true
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Scroll Tracking

    private func handleScroll(from old: ScrollMetrics, to new: ScrollMetrics) {
        // Ignore top bounce region
        guard new.offset > 10 && old.offset > 10 else {
            scrollAccumulator = 0
            return
        }

        // Ignore bottom bounce region
        let maxOffset = max(new.maxOffset, 0)
        guard new.offset < maxOffset - 10 && old.offset < maxOffset - 10 else {
            scrollAccumulator = 0
            return
        }

        let delta = new.offset - old.offset

        // Reset accumulator when scroll direction reverses
        if (delta > 0 && scrollAccumulator < 0) || (delta < 0 && scrollAccumulator > 0) {
            scrollAccumulator = 0
        }

        scrollAccumulator += delta

        let threshold: CGFloat = 30

        if scrollAccumulator > threshold && isFooterExpanded && selection != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isFooterExpanded = false
            }
            scrollAccumulator = 0
        } else if scrollAccumulator < -threshold && !isFooterExpanded {
            // Don't expand if still near the bottom — prevents bounce-back re-expansion
            guard new.offset < maxOffset - 100 else {
                scrollAccumulator = 0
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isFooterExpanded = true
            }
            scrollAccumulator = 0
        }
    }
}
