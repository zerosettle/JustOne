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
    @Environment(ZeroSettleManager.self) var iapManager
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.dismiss) var dismiss

    @State private var errorMessage: String?
    @State private var webCheckoutProduct: ZSProduct?
    @State private var isLoadingWebCheckout = false
    @State private var selection: ShopSelection? = .consumable(.streakSaver1)

    // Footer collapse/expand (Safari-style)
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

                        if !iapManager.isPremium {
                            subscriptionSection
                        }

                        // Spacing for footer
                        Color.clear.frame(height: 120)
                    }
                    .padding(.top, 20)
                }
                .onScrollGeometryChangeIfAvailable { old, new in
                    handleScroll(from: old, to: new)
                }

                // Fade haze behind footer
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

                // Morphing purchase footer
                purchaseFooter
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
            .checkoutSheet(
                item: $webCheckoutProduct,
                userId: authVM.appleUserID ?? "",
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
                    let error = await iapManager.processWebCheckout(result, userId: authVM.appleUserID)
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
                    subscriptionRow(tier)
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

            // Balance
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.justWarning)
                Text("Your Balance:")
                    .foregroundColor(.secondary)
                if iapManager.hasUnlimitedStreakSavers {
                    HStack(spacing: 4) {
                        Image(systemName: "infinity")
                        Text("Unlimited")
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.justSuccess)
                } else {
                    Text("\(iapManager.streakSaverTokens) tokens")
                        .fontWeight(.bold)
                }
            }

            // Product rows
            VStack(spacing: 12) {
                if !iapManager.hasUnlimitedStreakSavers {
                    unlimitedStreakSaverRow
                }

                ForEach(ConsumableProduct.allCases) { product in
                    consumableRow(product)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Subscription Row

    @ViewBuilder
    private func subscriptionRow(_ tier: SubscriptionTier) -> some View {
        let isSelected = selection == .subscription(tier)

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = .subscription(tier)
                isFooterExpanded = true
            }
        } label: {
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

                priceColumn(productId: tier.productId, fallbackPrice: tier.price)

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

    // MARK: - Price Column

    private func priceColumn(productId: String, fallbackPrice: String) -> some View {
        let zsProduct = ZeroSettle.shared.product(for: productId)

        return VStack(alignment: .trailing, spacing: 3) {
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

    // MARK: - Unlimited Streak Saver Row

    @ViewBuilder
    private var unlimitedStreakSaverRow: some View {
        let isSelected = selection == .unlimitedStreakSavers

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = .unlimitedStreakSavers
                isFooterExpanded = true
            }
        } label: {
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

                priceColumn(productId: StreakSaverSubscription.productId, fallbackPrice: StreakSaverSubscription.price)
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

    // MARK: - Consumable Row

    @ViewBuilder
    private func consumableRow(_ product: ConsumableProduct) -> some View {
        let isSelected = selection == .consumable(product)

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = .consumable(product)
                isFooterExpanded = true
            }
        } label: {
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

                priceColumn(productId: product.productId, fallbackPrice: product.price)

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

    // MARK: - Purchase Footer (Morphing)

    @ViewBuilder
    private var purchaseFooter: some View {
        if let selection {
            let zsProduct = ZeroSettle.shared.product(for: selection.productId)

            VStack(spacing: isFooterExpanded ? 10 : 0) {
                // Name row — always visible, style animates
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

                // Buttons — morph height, width, and opacity
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
            // Tap-to-expand overlay (only active when collapsed)
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
                Task {
                    do {
                        switch selection {
                        case .consumable(let product):
                            _ = try await iapManager.purchaseConsumable(product, userId: authVM.appleUserID)
                        case .subscription(let tier):
                            _ = try await iapManager.purchaseSubscription(tier, userId: authVM.appleUserID)
                        case .unlimitedStreakSavers:
                            _ = try await iapManager.purchaseStreakSaverSubscription(userId: authVM.appleUserID)
                        }
                    } catch where !ZeroSettleManager.isCancellation(error) {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        if iapManager.isPurchasing {
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
                .opacity(iapManager.isPurchasing ? 0.5 : 1.0)
            }
            .disabled(iapManager.isPurchasing)

            // Pay Direct button (only when web price exists)
            if let webPrice = zsProduct?.webPrice?.formatted {
                Button {
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
                    .opacity(iapManager.isPurchasing || isLoadingWebCheckout ? 0.7 : 1.0)
                }
                .disabled(iapManager.isPurchasing || isLoadingWebCheckout)
            }
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

// MARK: - Shop Selection

private enum ShopSelection: Equatable {
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

private struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let maxOffset: CGFloat
}

// MARK: - iOS 18+ Scroll Geometry Compatibility

private struct ScrollGeometryChangeModifier: ViewModifier {
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
    fileprivate func onScrollGeometryChangeIfAvailable(action: @escaping (ScrollMetrics, ScrollMetrics) -> Void) -> some View {
        modifier(ScrollGeometryChangeModifier(action: action))
    }
}
