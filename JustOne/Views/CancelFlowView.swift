//
//  CancelFlowView.swift
//  JustOne
//
//  Custom cancel flow UI using ZeroSettleKit's headless cancel flow API.
//  Presents a multi-step questionnaire with retention offers, styled
//  with JustOne's glass card design language.
//

import SwiftUI
import ZeroSettleKit
import StoreKit

struct CancelFlowView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PurchaseManager.self) var purchaseManager
    @Environment(AuthViewModel.self) var authViewModel

    var onResult: (CancelFlow.Result) -> Void = { _ in }

    @State private var config: CancelFlow.Config?
    @State private var currentQuestionIndex = 0
    @State private var answers: [CancelFlow.Answer] = []
    @State private var selectedOptionId: Int?
    @State private var freeTextInput = ""
    @State private var showingRetention = false
    @State private var offerShown = false
    @State private var pauseShown = false
    @State private var earlyOfferTriggered = false
    @State private var selectedPauseOptionId: Int?
    @State private var pauseExpanded = false
    @State private var isPauseLoading = false
    @State private var isOfferLoading = false
    @State private var isCancelLoading = false
    @State private var errorMessage: String?
    @State private var slideForward = true
    @State private var showConfetti = false
    @State private var confettiOrigin: CGPoint = .zero

    private var currentQuestion: CancelFlow.Question? {
        guard let config, currentQuestionIndex < config.questions.count else { return nil }
        return config.questions[currentQuestionIndex]
    }

    private var hasRetentionPage: Bool {
        guard let config else { return false }
        return (config.offer?.enabled == true) || (config.pause?.enabled == true)
    }

    private var totalSteps: Int {
        guard let config else { return 1 }
        if earlyOfferTriggered { return (currentQuestionIndex + 1) + 1 }
        return config.questions.count + (hasRetentionPage ? 1 : 0)
    }

    private var currentStep: Int {
        guard let config else { return 0 }
        if showingRetention {
            return earlyOfferTriggered ? currentQuestionIndex + 1 : config.questions.count
        }
        return currentQuestionIndex
    }

    private var canContinue: Bool {
        guard let question = currentQuestion else { return false }
        switch question.questionType {
        case .singleSelect:
            return selectedOptionId != nil || !question.isRequired
        case .freeText:
            return !freeTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !question.isRequired
        }
    }

    private var canGoBack: Bool {
        showingRetention || currentQuestionIndex > 0
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    LinearGradient.justBackground.ignoresSafeArea()

                    if config != nil {
                        flowContent
                    } else {
                        ProgressView()
                            .tint(.justPrimary)
                    }
                }
                .navigationTitle("Cancel Subscription")
                .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        submitAnalytics(outcome: .dismissed)
                        dismiss()
                        onResult(.dismissed)
                    }
                }
            }
            .task { await loadConfig() }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }

            if showConfetti {
                CancelConfettiView(origin: confettiOrigin)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "cancelFlowRoot")
        .onPreferenceChange(ButtonOriginKey.self) { origin in
            if let origin { confettiOrigin = CGPoint(x: origin.x + 100, y: origin.y + 26) }
        }
    }

    private var flowContent: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView(showsIndicators: false) {
                Group {
                    if showingRetention, let config {
                        CancelRetentionView(
                            config: config,
                            activeProductId: purchaseManager.activeSubscription?.productId ?? "",
                            selectedPauseOptionId: $selectedPauseOptionId,
                            pauseExpanded: $pauseExpanded
                        )
                    } else if let question = currentQuestion {
                        CancelSurveyView(
                            question: question,
                            selectedOptionId: $selectedOptionId,
                            freeTextInput: $freeTextInput
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .id(showingRetention ? -1 : currentQuestionIndex)
            .transition(.push(from: slideForward ? .trailing : .leading))

            CancelFlowButtonsView(
                showingRetention: showingRetention,
                canContinue: canContinue,
                canGoBack: canGoBack,
                config: config,
                pauseExpanded: $pauseExpanded,
                selectedPauseOptionId: selectedPauseOptionId,
                isOfferLoading: isOfferLoading,
                isPauseLoading: isPauseLoading,
                isCancelLoading: isCancelLoading,
                onGoBack: { goBack() },
                onContinue: { advanceToNext() },
                onAcceptOffer: { Task { await acceptOffer() } },
                onPause: { Task { await submitPause() } },
                onCancel: { Task { await performCancel() } }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.justPrimary : Color.secondary.opacity(0.2))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }

    // MARK: - Flow Logic

    private func loadConfig() async {
        if let cached = ZeroSettle.shared.cancelFlowConfig, cached.enabled, !cached.questions.isEmpty {
            config = cached
        } else {
            do {
                let fetched = try await ZeroSettle.shared.fetchCancelFlowConfig(userId: authViewModel.appleUserID)
                if fetched.enabled, !fetched.questions.isEmpty {
                    config = fetched
                } else {
                    dismiss()
                    onResult(.dismissed)
                }
            } catch {
                dismiss()
                onResult(.dismissed)
            }
        }
        #if DEBUG
        if let config {
            print("🔍 [CancelFlow] offer.enabled=\(config.offer?.enabled ?? false), pause.enabled=\(config.pause?.enabled ?? false), pauseOptions=\(config.pause?.options.count ?? 0)")
        }
        #endif
    }

    private func goBack() {
        slideForward = false

        if showingRetention {
            offerShown = false
            pauseShown = false
            earlyOfferTriggered = false
            selectedPauseOptionId = nil
            pauseExpanded = false
            if !answers.isEmpty { answers.removeLast() }
            selectedOptionId = nil
            withAnimation(.easeInOut(duration: 0.3)) { showingRetention = false }
        } else if currentQuestionIndex > 0 {
            if !answers.isEmpty {
                let removed = answers.removeLast()
                selectedOptionId = removed.selectedOptionId
                freeTextInput = removed.freeText ?? ""
            }
            withAnimation(.easeInOut(duration: 0.3)) { currentQuestionIndex -= 1 }
        }
    }

    private func advanceToNext() {
        guard let question = currentQuestion, let config else { return }
        slideForward = true

        let answer = CancelFlow.Answer(
            questionId: question.id,
            selectedOptionId: question.questionType == .singleSelect ? selectedOptionId : nil,
            freeText: question.questionType == .freeText ? freeTextInput.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
        answers.append(answer)

        // Check if selected option triggers early retention
        if question.questionType == .singleSelect,
           let optionId = selectedOptionId,
           let option = question.options.first(where: { $0.id == optionId }),
           (option.triggersOffer || option.triggersPause),
           hasRetentionPage {
            earlyOfferTriggered = true
            offerShown = config.offer?.enabled == true
            pauseShown = config.pause?.enabled == true
            withAnimation(.easeInOut(duration: 0.3)) { showingRetention = true }
            selectedOptionId = nil
            freeTextInput = ""
            return
        }

        let nextIndex = currentQuestionIndex + 1
        if nextIndex < config.questions.count {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentQuestionIndex = nextIndex
                selectedOptionId = nil
                freeTextInput = ""
            }
        } else if hasRetentionPage {
            offerShown = config.offer?.enabled == true
            pauseShown = config.pause?.enabled == true
            withAnimation(.easeInOut(duration: 0.3)) { showingRetention = true }
        } else {
            Task { await performCancel() }
        }
    }

    // MARK: - Terminal Actions

    private func acceptOffer() async {
        withAnimation(.spring(response: 0.4)) { showConfetti = true }
        submitAnalytics(outcome: .retained, offerAccepted: true)
        try? await Task.sleep(for: .seconds(2))
        dismiss()
        onResult(.retained)
    }

    private func submitPause() async {
        guard let pauseOptionId = selectedPauseOptionId,
              let productId = purchaseManager.activeSubscription?.productId,
              let userId = authViewModel.appleUserID else { return }
        let durationDays = config?.pause?.options.first { $0.id == pauseOptionId }?.durationDays
        isPauseLoading = true
        do {
            let resumesAt = try await ZeroSettle.shared.pauseSubscription(
                productId: productId,
                userId: userId,
                pauseDurationDays: durationDays
            )
            submitAnalytics(outcome: .paused, pauseAccepted: true, pauseDurationDays: durationDays)
            dismiss()
            onResult(.paused(resumesAt: resumesAt))
        } catch {
            isPauseLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func performCancel() async {
        guard let tier = purchaseManager.activeSubscription,
              let userId = authViewModel.appleUserID else { return }
        isCancelLoading = true

        submitAnalytics(outcome: .cancelled)

        if purchaseManager.isStoreKitBilling {
            // Apple doesn't allow programmatic cancellation — open system settings
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                try? await AppStore.showManageSubscriptions(in: windowScene)
            }
            // Sheet dismissal doesn't fire Transaction.updates — refresh explicitly.
            await purchaseManager.syncWithSDK(userId: userId)
        } else {
            do {
                try await ZeroSettle.shared.cancelSubscription(productId: tier.productId, userId: userId)
                await purchaseManager.syncWithSDK(userId: userId)
            } catch {
                isCancelLoading = false
                errorMessage = "Failed to cancel: \(error.localizedDescription)"
                return
            }
        }

        dismiss()
        onResult(.cancelled)
    }

    // MARK: - Analytics

    private func submitAnalytics(
        outcome: CancelFlow.Outcome,
        offerAccepted: Bool = false,
        pauseAccepted: Bool = false,
        pauseDurationDays: Int? = nil
    ) {
        let response = CancelFlow.Response(
            productId: purchaseManager.activeSubscription?.productId ?? "",
            userId: authViewModel.appleUserID ?? "",
            outcome: outcome,
            answers: answers,
            offerShown: offerShown,
            offerAccepted: offerAccepted,
            pauseShown: pauseShown,
            pauseAccepted: pauseAccepted,
            pauseDurationDays: pauseDurationDays
        )
        Task { await ZeroSettle.shared.submitCancelFlowResponse(response) }
    }
}
