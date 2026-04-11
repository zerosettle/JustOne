//
//  LaunchPaywallView.swift
//  JustOne
//
//  Full-screen paywall shown on launch for marketing videos.
//

import SwiftUI
import ZeroSettleKit

struct LaunchPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PurchaseManager.self) var purchaseManager
    @Environment(AuthViewModel.self) var authViewModel
    @State private var appeared = false
    @State private var selectedTier: SubscriptionTier = .yearly
    @State private var webCheckoutProduct: ZSProduct?
    @State private var isLoadingWebCheckout = false
    @State private var errorMessage: String?

    private let tiers: [(tier: SubscriptionTier, badge: String?)] = [
        (.weekly, nil),
        (.monthly, nil),
        (.yearly, "MOST POPULAR"),
    ]

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("infinity", "Unlimited Habits", "Track as many habits as you want"),
        ("chart.line.uptrend.xyaxis", "Advanced Analytics", "Deep insights into your progress"),
        ("heart.fill", "Health Sync", "Auto-complete with Apple Health"),
        ("arrow.up.arrow.down", "Custom Ordering", "Stack habits your way"),
        ("bell.badge.fill", "Smart Reminders", "Perfectly timed nudges"),
        ("icloud.fill", "Cloud Sync", "Seamless across all devices"),
    ]

    var body: some View {
        ZStack {
            // Background
            LinearGradient.justBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Close button
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(.top, 8)

                    // Hero
                    heroSection
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)

                    // Features
                    featureGrid
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)

                    // Plan cards
                    planCards
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)

                    // Free trial banner
                    if let label = selectedTier.freeTrialLabel {
                        HStack(spacing: 6) {
                            Image(systemName: "gift.fill")
                                .font(.caption)
                            Text("Start your \(label)")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.justSuccess)
                        .transition(.opacity)
                    }

                    // CTA
                    ctaButton
                        .offset(y: appeared ? 0 : 50)
                        .opacity(appeared ? 1 : 0)

                    // Legal
                    legalFooter
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
        .task {
            if let userId = authViewModel.appleUserID {
                await CheckoutSheet.warmUp(productId: selectedTier.productId, userId: userId)
            }
        }
        .onChange(of: selectedTier) { _, newTier in
            Task {
                if let userId = authViewModel.appleUserID {
                    await CheckoutSheet.warmUp(productId: newTier.productId, userId: userId)
                }
            }
        }
        .checkoutSheet(
            item: $webCheckoutProduct,
            userId: authViewModel.appleUserID ?? "",
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
                if case .success = result { dismiss() }
            }
        }
        .resetLoadingOnBackground($isLoadingWebCheckout)
        .alert("Purchase Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient.premiumGradient)
                    .frame(height: 120)

                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    Text("PRO")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(spacing: 8) {
                Text("Unlock Your Full Potential")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Build habits that stick, with powerful tools to keep you on track")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Feature Grid

    private var featureGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                HStack(spacing: 10) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16))
                        .foregroundColor(.justPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.justPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(feature.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(feature.subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(10)
                .glassCard(cornerRadius: 14)
            }
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        HStack(spacing: 10) {
            ForEach(tiers, id: \.tier) { entry in
                let tier = entry.tier
                let isSelected = selectedTier == tier

                Button { withAnimation(.spring(response: 0.3)) { selectedTier = tier } } label: {
                    VStack(spacing: 8) {
                        Text(tier.displayName)
                            .font(.system(size: 14, weight: .semibold))

                        Text(tier.price)
                            .font(.system(size: 20, weight: .bold, design: .rounded))

                        Text(tier.pricePerMonth)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        if let label = tier.freeTrialLabel {
                            Text(label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.justSuccess)
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.justSurface.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.justPrimary : Color.black.opacity(0.06),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    )
                    // Badge rendered AFTER the stroke so it sits on top
                    .overlay(alignment: .top) {
                        if let badge = entry.badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .heavy))
                                .tracking(0.3)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.justPrimary)
                                .clipShape(Capsule())
                                .offset(y: -8)
                        }
                    }
                    .shadow(color: .black.opacity(isSelected ? 0.10 : 0.04), radius: isSelected ? 8 : 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            if let zsProduct = ZeroSettle.shared.product(for: selectedTier.productId) {
                isLoadingWebCheckout = true
                webCheckoutProduct = zsProduct
            }
        } label: {
            Group {
                if isLoadingWebCheckout {
                    ProgressView().tint(.white)
                } else {
                    Text(selectedTier.freeTrialLabel != nil ? "Start Free Trial" : "Continue")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(LinearGradient.premiumGradient, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.justPrimary.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isLoadingWebCheckout)
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: 4) {
            Button("Restore Purchases") {
                Task {
                    do {
                        try await purchaseManager.restorePurchases(userId: authViewModel.appleUserID)
                    } catch where !ZeroSettleError.isCancellation(error) {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text("Cancel anytime \u{00B7} No commitment")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
}
