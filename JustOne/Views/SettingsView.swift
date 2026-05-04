//
//  SettingsView.swift
//  JustOne
//
//  Account screen showing progress snapshot, weekly reflection,
//  subscription status, streak saver balance, and support.
//

import SwiftUI
import SwiftData
import StoreKit
import ZeroSettleKit

struct SettingsView: View {
    @Query var habits: [Habit]
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(PurchaseManager.self) var purchaseManager

    @State private var showPremiumUpsell = false
    @State private var showConsumableShop = false
    @State private var showRestoreConfirmation = false
    @State private var errorMessage: String?
    @State private var showAnnualUpgrade = false
    @State private var isUpgradeAvailable = false
    @State private var showCancelFlow = false
    @State private var showFallbackCancel = false
    @State private var reminderEnabled = NotificationManager.isReminderEnabled
    @State private var reminderTime = {
        let comps = NotificationManager.reminderTimeComponents
        return Calendar.current.date(from: comps) ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    }()

    // MARK: - Body

    var body: some View {
        mainContent
            // SDK PATTERN: .upgradeOffer() for backend-driven plan upgrade UI.
            // Shows a native upgrade sheet with price comparison and prorated refund.
            .upgradeOffer(
                isPresented: $showAnnualUpgrade,
                productId: SubscriptionTier.yearly.productId,
                userId: authViewModel.appleUserID ?? "",
                onResult: { result in
                    if case .upgraded = result {
                        Task { await purchaseManager.syncWithSDK(userId: authViewModel.appleUserID ?? "") }
                    }
                }
            )
            // SDK PATTERN: .cancelFlow() for retention/cancellation flow.
            // Presents a backend-configured retention offer before cancelling.
            .cancelFlow(
                isPresented: $showCancelFlow,
                productId: purchaseManager.activeSubscription?.productId ?? "",
                userId: authViewModel.appleUserID ?? "",
                onResult: { result in
                    switch result {
                    case .cancelled, .paused:
                        Task { await purchaseManager.syncWithSDK(userId: authViewModel.appleUserID ?? "") }
                    case .dismissed:
                        // Cancel flow not configured — show fallback cancel UI
                        showFallbackCancel = true
                    case .retained:
                        break
                    }
                }
            )
    }

    private var mainContent: some View {
        ZStack {
            LinearGradient.justBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    AccountCardView(user: authViewModel.currentUser, habits: habits, zeroSettleUserId: authViewModel.appleUserID)
                    weeklyReflectionCard

                    VStack(alignment: .leading, spacing: 6) {
                        #if DEBUG
                        if ZSOfferManager.demoMode.isActive {
                            HStack(spacing: 6) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.caption2.weight(.bold))
                                Text("DEMO MODE — \(ZSOfferManager.demoMode.displayLabel)")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange, in: Capsule())
                        }
                        #endif

                        OfferTipView(userId: authViewModel.appleUserID ?? "")
                    }

                    SubscriptionCardView(
                        showPremiumUpsell: $showPremiumUpsell,
                        showAnnualUpgrade: $showAnnualUpgrade,
                        showCancelFlow: $showCancelFlow,
                        isUpgradeAvailable: isUpgradeAvailable
                    )
                    StreakSaverCardView(showConsumableShop: $showConsumableShop)
                    ReminderCardView(reminderEnabled: $reminderEnabled, reminderTime: $reminderTime)
                    supportSection

                    #if DEBUG
                    NavigationLink {
                        DebugSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.orange)
                            Text("Debug Environment")
                                .font(.subheadline)
                            Spacer()
                            Text("\(DebugEnvironment.server.displayName) · \(DebugEnvironment.mode.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .glassCard()
                    }
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremiumUpsell) {
            PremiumUpsellView()
        }
        .fullScreenCover(isPresented: $showConsumableShop) {
            ConsumableShopView()
        }
        .alert("Purchases Restored", isPresented: $showRestoreConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your purchases have been restored successfully.")
        }
        .task {
            guard authViewModel.appleUserID != nil else { return }

            // Offer checkout warmup handled internally by OfferCardView's .checkoutSheet

            // Check if an upgrade offer is available from the backend
            if purchaseManager.canUpgradeToAnnual {
                do {
                    let config = try await ZeroSettle.shared.fetchUpgradeOfferConfig(
                        productId: SubscriptionTier.yearly.productId
                    )
                    isUpgradeAvailable = config.available
                } catch {
                    isUpgradeAvailable = false
                }
            }
        }
        .alert(
            "Cancel Subscription?",
            isPresented: $showFallbackCancel
        ) {
            if purchaseManager.isStoreKitBilling {
                Button("Manage in Settings") {
                    Task { await openManageSubscriptions() }
                }
                Button("Never mind", role: .cancel) {}
            } else {
                Button("Cancel Subscription", role: .destructive) {
                    Task { await cancelDirectBilling() }
                }
                Button("Never mind", role: .cancel) {}
            }
        } message: {
            if purchaseManager.isStoreKitBilling {
                Text("Your subscription is managed through Apple. You'll be taken to your subscription settings.")
            } else {
                Text("Your subscription will remain active until the end of your current billing period.")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Weekly Reflection Card

    private var weeklyReflectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.justPrimary)
                Text("This Week")
                    .font(.headline)
                Spacer()
            }

            if habits.isEmpty {
                Text("Add a habit to see your weekly progress here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let completed = habits.filter { $0.weeklyProgress() >= 1.0 }.count

                Text(weeklyReflectionMessage(completed: completed, total: habits.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(habits) { habit in
                    HStack(spacing: 12) {
                        Image(systemName: habit.icon)
                            .font(.caption)
                            .foregroundColor(habit.displayColor)
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)

                        Text(habit.name)
                            .font(.subheadline)

                        Spacer()

                        Text("\(habit.completionsInWeek())/\(habit.frequencyPerWeek)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(habit.weeklyProgress() >= 1.0 ? .justSuccess : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(habit.name), \(habit.completionsInWeek()) of \(habit.frequencyPerWeek) completions this week")
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    private func weeklyReflectionMessage(completed: Int, total: Int) -> String {
        if completed == total {
            return "You hit every goal this week. That's consistency."
        } else if completed > 0 {
            return "You showed up for \(completed) of \(total) habits this week. Keep building."
        } else {
            return "New week, fresh start. You've got this."
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    do {
                        try await purchaseManager.restorePurchases(userId: authViewModel.appleUserID)
                        showRestoreConfirmation = true
                    } catch where !ZeroSettleError.isCancellation(error) {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Restore Purchases")
                    Spacer()
                    if purchaseManager.isPurchasing {
                        ProgressView()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(16)
                .glassCard()
            }
            .disabled(purchaseManager.isPurchasing)
            .accessibilityHint("Restores previous purchases from the App Store")

            HStack {
                Spacer()
                VStack(spacing: 2) {
                    if let joined = authViewModel.currentUser?.joinedAt {
                        Text("Member since \(joined.formatted(.dateTime.month(.wide).year()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("JustOne v1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func openManageSubscriptions() async {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        try? await AppStore.showManageSubscriptions(in: windowScene)
        // Apple's sheet dismissal doesn't fire Transaction.updates — refresh
        // entitlements explicitly so the UI reflects any willRenew change.
        if let userId = authViewModel.appleUserID {
            await purchaseManager.syncWithSDK(userId: userId)
        }
    }

    @MainActor
    private func cancelDirectBilling() async {
        guard let tier = purchaseManager.activeSubscription,
              let userId = authViewModel.appleUserID else { return }
        do {
            try await ZeroSettle.shared.cancelSubscription(productId: tier.productId)
            await purchaseManager.syncWithSDK(userId: userId)
        } catch {
            errorMessage = "Failed to cancel: \(error.localizedDescription)"
        }
    }
}
