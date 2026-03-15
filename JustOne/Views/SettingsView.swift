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
    @State private var webCheckoutProduct: ZSProduct?
    @State private var isMigrationLoading = false
    @State private var reminderEnabled = NotificationManager.isReminderEnabled
    @State private var reminderTime = {
        let comps = NotificationManager.reminderTimeComponents
        return Calendar.current.date(from: comps) ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0))!
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
                    AccountCardView(user: authViewModel.currentUser, habits: habits)
                    weeklyReflectionCard

                    // SDK PATTERN: Migration banner for StoreKit→web Switch & Save.
                    // migrationManager is non-nil when the user is eligible to
                    // migrate from StoreKit billing to direct billing at a discount.
                    if let manager = ZeroSettle.shared.migrationManager,
                       manager.state == .eligible || manager.state == .presented,
                       let offer = manager.offerData {
                        migrationBanner(manager: manager, offer: offer)
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
        // SDK PATTERN: .checkoutSheet presents web checkout overlay.
        // This instance tracks Switch & Save conversion on success.
        // Free trials are configured server-side.
        .checkoutSheet(
            item: $webCheckoutProduct,
            userId: authViewModel.appleUserID ?? "",
            preload: .all
        ) {
            if let product = webCheckoutProduct {
                CheckoutSheetHeader(product: product)
            }
        } onComplete: { result in
            isMigrationLoading = false
            Task {
                errorMessage = await purchaseManager.processWebCheckout(result, userId: authViewModel.appleUserID)
                // If this was a migration checkout, track the conversion
                if case .success = result,
                   let manager = ZeroSettle.shared.migrationManager,
                   manager.state == .presented {
                    await manager.markCheckoutSucceeded()
                    await manager.showAppleSubscriptionManagement()
                }
            }
        }
        .task {
            guard let userId = authViewModel.appleUserID else { return }

            // Warm up the active subscription tier's checkout
            if let tier = purchaseManager.activeSubscription {
                await CheckoutSheet.warmUp(productId: tier.productId, userId: userId)
            }

            // Warm up the migration product's checkout if eligible
            if let productId = ZeroSettle.shared.migrationManager?.offerData?.prompt.productId {
                await CheckoutSheet.warmUp(productId: productId, userId: userId)
            }

            // Check if an upgrade offer is available from the backend
            if purchaseManager.canUpgradeToAnnual {
                do {
                    let config = try await ZeroSettle.shared.fetchUpgradeOfferConfig(
                        productId: SubscriptionTier.yearly.productId,
                        userId: userId
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

                        Text(habit.name)
                            .font(.subheadline)

                        Spacer()

                        Text("\(habit.completionsInWeek())/\(habit.frequencyPerWeek)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(habit.weeklyProgress() >= 1.0 ? .justSuccess : .secondary)
                    }
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

    // MARK: - Migration Banner

    private func migrationBanner(manager: ZSMigrationManager, offer: MigrationOffer.OfferData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .font(.title3)
                    .foregroundColor(.justSuccess)

                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.prompt.title)
                        .font(.headline)

                    Text(offer.prompt.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if offer.freeTrialDays > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.caption)
                        .foregroundColor(.justPrimary)
                    Text("\(offer.freeTrialDays) free days included")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.justPrimary)
                }
            }

            Button {
                isMigrationLoading = true
                manager.present()
                if let product = ZeroSettle.shared.product(for: offer.prompt.productId) {
                    webCheckoutProduct = product
                } else {
                    isMigrationLoading = false
                }
            } label: {
                Group {
                    if isMigrationLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(offer.prompt.ctaText)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(LinearGradient.savingsGradient, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isMigrationLoading)

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
    }

    @MainActor
    private func cancelDirectBilling() async {
        guard let tier = purchaseManager.activeSubscription,
              let userId = authViewModel.appleUserID else { return }
        do {
            try await ZeroSettle.shared.cancelSubscription(
                productId: tier.productId,
                userId: userId
            )
            await purchaseManager.syncWithSDK(userId: userId)
        } catch {
            errorMessage = "Failed to cancel: \(error.localizedDescription)"
        }
    }
}
