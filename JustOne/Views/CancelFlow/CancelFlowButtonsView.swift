//
//  CancelFlowButtonsView.swift
//  JustOne
//
//  Bottom action buttons for the cancel flow — handles both the
//  survey navigation buttons and retention offer/pause CTA buttons.
//

import SwiftUI
import ZeroSettleKit

struct CancelFlowButtonsView: View {
    let showingRetention: Bool
    let canContinue: Bool
    let canGoBack: Bool
    let config: CancelFlow.Config?

    @Binding var pauseExpanded: Bool
    let selectedPauseOptionId: Int?
    let isOfferLoading: Bool
    let isPauseLoading: Bool
    let isCancelLoading: Bool

    var onGoBack: () -> Void
    var onContinue: () -> Void
    var onAcceptOffer: () -> Void
    var onPause: () -> Void
    var onCancel: () -> Void

    var body: some View {
        if showingRetention {
            retentionButtons
        } else {
            questionButtons
        }
    }

    // MARK: - Question Buttons

    private var questionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if canGoBack {
                    Button { onGoBack() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(width: 52, height: 52)
                            .background(Color.justSurface, in: RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button { onContinue() } label: {
                    Text("Continue")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            canContinue ? LinearGradient.premiumGradient : LinearGradient(colors: [Color.secondary.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .disabled(!canContinue)
            }

            Button {
                onCancel()
            } label: {
                Text("Skip and cancel subscription")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .disabled(isCancelLoading)
        }
    }

    // MARK: - Retention Buttons

    @ViewBuilder
    private var retentionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { onGoBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 52, height: 52)
                        .background(Color.justSurface, in: RoundedRectangle(cornerRadius: 14))
                }

                if config?.offer?.enabled == true {
                    Button {
                        onAcceptOffer()
                    } label: {
                        Group {
                            if isOfferLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(config?.offer?.ctaText ?? "Accept Offer")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(LinearGradient.premiumGradient, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isOfferLoading || isPauseLoading)
                    .overlay(GeometryReader { geo in
                        Color.clear.preference(
                            key: ButtonOriginKey.self,
                            value: geo.frame(in: .named("cancelFlowRoot")).origin
                        )
                    })
                }
            }

            if pauseExpanded, config?.pause?.enabled == true {
                Button { onPause() } label: {
                    Group {
                        if isPauseLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(config?.pause?.ctaText ?? "Pause Subscription")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        selectedPauseOptionId != nil ? Color.justSecondary : Color.justSecondary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(selectedPauseOptionId == nil || isPauseLoading || isOfferLoading)
            }

            Button {
                onCancel()
            } label: {
                if isCancelLoading {
                    ProgressView()
                        .tint(.secondary)
                } else {
                    Text("No thanks, cancel")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(isCancelLoading || isOfferLoading || isPauseLoading)
        }
    }
}

// MARK: - Preference Key

struct ButtonOriginKey: PreferenceKey {
    static var defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
        value = nextValue() ?? value
    }
}
