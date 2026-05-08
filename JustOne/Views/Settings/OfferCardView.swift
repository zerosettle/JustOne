//
//  OfferCardView.swift
//  JustOne
//
//  Custom offer card for migration and upgrade flows.
//  Uses ZSOfferManager for state and checkout — demonstrates
//  building a fully custom offer UI with the ZeroSettleKit SDK.
//

import SwiftUI
import ZeroSettleKit

struct OfferCardView: View {
    let userId: String
    var onCheckoutCompleted: (() -> Void)?

    @ObservedObject private var manager: ZSOfferManager
    @State private var isCheckoutLoading = false
    @State private var webCheckoutProduct: ZSProduct?

    init(userId: String, onCheckoutCompleted: (() -> Void)? = nil) {
        self.userId = userId
        self.onCheckoutCompleted = onCheckoutCompleted
        // `offerManager()` is non-throwing as of ZeroSettleKit 1.3.4 — it
        // returns a single shared instance that auto-promotes when identify
        // runs, so safe to construct this view before sign-in completes.
        _manager = ObservedObject(wrappedValue: ZeroSettle.shared.offerManager())
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch manager.state {
            case .eligible, .presented:
                offerCard
            case .accepted:
                acceptedCard
            default:
                EmptyView()
            }
        }
        // SDK PATTERN: .checkoutSheet presents the checkout overlay when the
        // CTA is tapped. The ZSOfferManager handles state transitions; this
        // view just wires up the presentation and completion handlers.
        .checkoutSheet(
            item: $webCheckoutProduct,
            userId: userId,
            onPresent: { isCheckoutLoading = false }
        ) { result in
            isCheckoutLoading = false
            if case .success = result {
                Task {
                    await manager.markCheckoutSucceeded()
                    onCheckoutCompleted?()
                }
            }
        }
        .resetLoadingOnBackground($isCheckoutLoading)
    }

    // MARK: - Offer Card

    private var offerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .font(.title3)
                    .foregroundColor(.justSuccess)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.display?.offerTitleOrDefault(defaultTitle) ?? defaultTitle)
                        .font(.headline)

                    Text(manager.display?.offerMessageOrDefault(defaultMessage) ?? defaultMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let data = manager.offerData, data.freeTrialDays > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.caption)
                        .foregroundColor(.justPrimary)
                    Text("\(data.freeTrialDays) free days included")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.justPrimary)
                }
            }

            Button {
                handleCtaTapped()
            } label: {
                Group {
                    if isCheckoutLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(manager.display?.offerCtaOrDefault(defaultCta) ?? defaultCta)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(LinearGradient.savingsGradient, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isCheckoutLoading)
            .accessibilityHint("Opens checkout to switch to direct billing")

            Button {
                manager.dismiss()
            } label: {
                Text("No thanks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Accepted Card

    private var acceptedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.justSuccess)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.display?.acceptedTitleOrDefault("You're all set!") ?? "You're all set!")
                        .font(.headline)

                    Text(manager.display?.acceptedMessageOrDefault("Cancel your Apple subscription to complete the switch.") ?? "Cancel your Apple subscription to complete the switch.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                Task {
                    await manager.showAppleSubscriptionManagement()
                }
            } label: {
                Text(manager.display?.acceptedCtaOrDefault("Manage Subscription") ?? "Manage Subscription")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.justPrimary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Actions

    private func handleCtaTapped() {
        guard let data = manager.offerData,
              let product = ZeroSettle.shared.product(for: data.checkoutProductId) else { return }
        isCheckoutLoading = true
        manager.present()
        webCheckoutProduct = product
    }

    // MARK: - Default Copy

    private var savings: Int { manager.offerData?.savingsPercent ?? 0 }

    private var defaultTitle: String { "Switch & Save" }

    private var defaultMessage: String {
        savings > 0
            ? "Switch to direct billing and get \(savings)% off forever. Same features, fewer platform fees."
            : "Switch to direct billing. Same features, fewer platform fees."
    }

    private var defaultCta: String {
        savings > 0 ? "Save \(savings)% Forever" : "Switch Now"
    }
}
