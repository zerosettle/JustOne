//
//  CancelRetentionView.swift
//  JustOne
//
//  Retention offer and pause option sections for the cancel flow.
//  Shows discount offers and expandable pause duration picker.
//

import SwiftUI
import ZeroSettleKit

struct CancelRetentionView: View {
    let config: CancelFlow.Config
    let activeProductId: String
    @Binding var selectedPauseOptionId: Int?
    @Binding var pauseExpanded: Bool

    var body: some View {
        VStack(spacing: 24) {
            if let offer = config.offer, offer.enabled {
                offerSection(offer)
            }

            if let pauseConfig = config.pause, pauseConfig.enabled, !pauseConfig.options.isEmpty {
                pauseSection(pauseConfig)
            }
        }
    }

    // MARK: - Offer Section

    private func offerSection(_ offer: CancelFlow.Offer) -> some View {
        let product = ZeroSettle.shared.product(for: activeProductId)
        let currentPrice = product?.webPrice ?? product?.storeKitPrice
        let discountPercent = Int(offer.value) ?? 0

        return VStack(spacing: 20) {
            Image(systemName: "gift.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.premiumGradient)

            Text(offer.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(offer.body)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let price = currentPrice, discountPercent > 0 {
                let discountedCents = Int((Double(price.amountCents) * Double(100 - discountPercent) / 100.0).rounded())
                let discountedPrice = Price(amountCents: discountedCents, currencyCode: price.currencyCode)
                let period: String = {
                    guard product?.type == .autoRenewableSubscription else { return "" }
                    switch product?.billingInterval {
                    case "week": return " / week"
                    case "year": return " / year"
                    default: return " / month"
                    }
                }()

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Text(price.formatted)
                            .font(.title3)
                            .strikethrough()
                            .foregroundColor(.secondary)

                        Text(discountedPrice.formatted + period)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.justSuccess)
                    }

                    if let months = offer.durationMonths {
                        Text("\(discountPercent)% off for \(months) month\(months == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.justSuccess, in: Capsule())
                    }
                }
                .padding(20)
                .glassCard()
            }
        }
    }

    // MARK: - Pause Section

    private func pauseSection(_ pauseConfig: CancelFlow.PauseConfig) -> some View {
        VStack(spacing: 12) {
            if config.offer?.enabled == true {
                Divider()
                    .padding(.vertical, 4)
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    pauseExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title3)
                        .foregroundColor(pauseExpanded ? .justSecondary : .secondary)
                        .frame(width: 48, height: 48)
                        .background(
                            pauseExpanded ? Color.justSecondary.opacity(0.12) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 14)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pauseConfig.title)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        Text(pauseConfig.body)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(pauseExpanded ? 180 : 0))
                }
                .padding(20)
                .glassCard()
            }
            .buttonStyle(LiquidPressStyle())

            if pauseExpanded {
                VStack(spacing: 10) {
                    let sorted = pauseConfig.options.sorted { $0.order < $1.order }
                    ForEach(sorted) { option in
                        let isSelected = selectedPauseOptionId == option.id
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPauseOptionId = option.id
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "clock.fill")
                                    .font(.title3)
                                    .foregroundColor(isSelected ? .justSecondary : .secondary)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        isSelected ? Color.justSecondary.opacity(0.12) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )

                                Text(option.label)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)

                                Spacer(minLength: 8)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.justSecondary)
                                    .opacity(isSelected ? 1 : 0)
                            }
                            .padding(20)
                            .glassCard()
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isSelected ? Color.justSecondary : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(LiquidPressStyle())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
