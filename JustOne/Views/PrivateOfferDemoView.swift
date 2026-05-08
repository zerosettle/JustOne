//
//  PrivateOfferDemoView.swift
//  JustOne
//
//  Bespoke marketing splash that wraps the framework-vended OfferTipView as
//  its CTA surface. The header, hero card, headline, and comparison cards are
//  fully custom; the conversion button at the bottom is OfferTipView so the
//  switch & save flow runs through the SDK exactly as in production.
//

import SwiftUI
import ZeroSettleKit

struct PrivateOfferDemoView: View {
    let userId: String
    var onDismiss: () -> Void

    @ObservedObject private var manager: ZSOfferManager
    @State private var isCheckoutLoading = false
    @State private var webCheckoutProduct: ZSProduct?

    init(userId: String, onDismiss: @escaping () -> Void) {
        self.userId = userId
        self.onDismiss = onDismiss
        // `offerManager()` is non-throwing as of ZeroSettleKit 1.3.4 — it
        // returns a single shared instance that auto-promotes when identify
        // runs.
        _manager = ObservedObject(wrappedValue: ZeroSettle.shared.offerManager())
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        heroCard
                        headline
                        subtitle
                        comparisonRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }

                claimSection
                    .padding(.horizontal, 24)

                footer
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .checkoutSheet(
            item: $webCheckoutProduct,
            userId: userId,
            onPresent: { isCheckoutLoading = false }
        ) { result in
            isCheckoutLoading = false
            if case .success = result {
                Task {
                    await manager.markCheckoutSucceeded()
                }
            }
        }
        .resetLoadingOnBackground($isCheckoutLoading)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color.justSecondary.opacity(0.22), .clear],
                center: .init(x: 0.5, y: 0.05),
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(LinearGradient.premiumGradient)
                    Text("JustOne")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(.white)
                }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(standardPrice)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .strikethrough()
                    Text(yourPrice)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(Color.justSecondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.justSecondary.opacity(0.18), radius: 28, x: 0, y: 12)

            HStack(spacing: 6) {
                Text(savingsString)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundColor(.black)
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Text("J")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(Color.justSecondary)
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.justSecondary))
            .offset(x: -14, y: -10)
        }
        .padding(.top, 12)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: -4) {
            Text("a private")
                .foregroundColor(Color.justSecondary)
            Text("offer")
                .foregroundColor(.white)
        }
        .font(.system(size: 44, weight: .bold, design: .rounded))
        .multilineTextAlignment(.center)
    }

    // MARK: - Subtitle

    private var subtitle: some View {
        Text("Just for you: bill directly with JustOne and pay \(savingsPercent)% less every week. Your subscription stays exactly the same.")
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
    }

    // MARK: - Comparison Row

    private var comparisonRow: some View {
        HStack(alignment: .center, spacing: 8) {
            standardCard
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
            yourPriceCard
        }
    }

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STANDARD")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1)
            Text(standardPrice)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .strikethrough()
            Text("per week")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var yourPriceCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR PRICE")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundColor(Color.justSecondary)
                    .tracking(1)
                Text(yourPrice)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                Text("per week")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [Color.justSecondary.opacity(0.22), Color.justSecondary.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.justSecondary.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Color.justSecondary.opacity(0.25), radius: 14, x: 0, y: 6)

            Text(savingsString)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.justSecondary))
                .offset(x: -8, y: -8)
        }
    }

    // MARK: - Claim Section (headless ZSOfferManager-driven CTA)

    @ViewBuilder
    private var claimSection: some View {
        switch manager.state {
        case .ineligible, .dismissed:
            ineligibleFallback
        case .accepted:
            appleCancelButton
        case .completed:
            completedNote
        default:
            claimButton
        }
    }

    private var claimButton: some View {
        Button(action: handleCtaTapped) {
            ZStack {
                if isCheckoutLoading {
                    ProgressView()
                        .tint(.black.opacity(0.7))
                } else {
                    Text(ctaLabel)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(.black.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.justSecondary.opacity(0.30), radius: 22, x: 0, y: 8)
        }
        .buttonStyle(LiquidPressStyle())
        .disabled(isCheckoutLoading || manager.offerData == nil)
        .accessibilityHint("Opens checkout to switch to direct billing")
    }

    private var appleCancelButton: some View {
        Button {
            Task { await manager.showAppleSubscriptionManagement() }
        } label: {
            Text(manager.display?.acceptedCtaOrDefault("Cancel Apple Subscription") ?? "Cancel Apple Subscription")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(Color.justSecondary))
        }
        .buttonStyle(LiquidPressStyle())
    }

    private var completedNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.justSuccess)
            Text("You're all set — direct billing active.")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(Color.justSuccess.opacity(0.4), lineWidth: 1))
    }

    private var ineligibleFallback: some View {
        VStack(spacing: 6) {
            Text("No active offer for this account")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
            Text("Sign in to an account with an active Apple subscription to surface the Switch & Save offer.")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func handleCtaTapped() {
        guard let data = manager.offerData,
              let product = ZeroSettle.shared.product(for: data.checkoutProductId) else { return }
        isCheckoutLoading = true
        manager.present()
        webCheckoutProduct = product
    }

    private var ctaLabel: String {
        let fallback = "Claim my \(savingsPercent)%"
        return manager.display?.offerCtaOrDefault(fallback) ?? fallback
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Seamless transition. Cancel anytime.")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
            Button("Maybe later", action: onDismiss)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.top, 8)
    }

    // MARK: - Data

    private var savingsPercent: Int {
        manager.offerData?.savingsPercent ?? 15
    }

    private var savingsString: String { "-\(savingsPercent)%" }

    private var standardPrice: String {
        let fromId = manager.offerData?.fromProductId ?? manager.offerData?.productId
        if let fromId, let sk = ZeroSettle.shared.product(for: fromId)?.storeKitPrice?.formatted {
            return sk
        }
        return "$14.99"
    }

    private var yourPrice: String {
        if let toId = manager.offerData?.checkoutProductId,
           let web = ZeroSettle.shared.product(for: toId)?.webPrice?.formatted {
            return web
        }
        return "$12.74"
    }
}
