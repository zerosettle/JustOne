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
    @Environment(AuthViewModel.self) var authVM
    @Environment(ZeroSettleManager.self) var iapManager

    @State private var showPremiumUpsell = false
    @State private var showConsumableShop = false
    @State private var showRestoreConfirmation = false
    @State private var errorMessage: String?
    @State private var showAnnualUpgrade = false
    @State private var isUpgradeAvailable = false
    @State private var showCancelFlow = false
    @State private var showFallbackCancel = false
    @State private var webCheckoutProduct: ZSProduct?
    @State private var reminderEnabled = NotificationManager.isReminderEnabled
    @State private var reminderTime = {
        let comps = NotificationManager.reminderTimeComponents
        return Calendar.current.date(from: comps) ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0))!
    }()

    // MARK: - Aggregate Stats

    private var longestStreak: Int {
        habits.map(\.currentStreak).max() ?? 0
    }

    private var consistencyThisMonth: Int {
        let calendar = Calendar.current
        let today = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: today) else { return 0 }

        let daysElapsed = max(calendar.dateComponents([.day], from: monthInterval.start, to: today).day ?? 0, 1)

        var totalExpected = 0
        var totalCompleted = 0

        for habit in habits {
            let dailyRate = Double(habit.frequencyPerWeek) / 7.0
            totalExpected += Int(ceil(dailyRate * Double(daysElapsed)))

            var day = monthInterval.start
            while day <= today {
                if habit.isCompleted(on: day) { totalCompleted += 1 }
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
        }

        guard totalExpected > 0 else { return 0 }
        return min(Int(Double(totalCompleted) / Double(totalExpected) * 100), 100)
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .upgradeOffer(
                isPresented: $showAnnualUpgrade,
                productId: SubscriptionTier.yearly.productId,
                userId: authVM.appleUserID ?? "",
                onResult: { result in
                    if case .upgraded = result {
                        Task { await iapManager.syncWithSDK(userId: authVM.appleUserID ?? "") }
                    }
                }
            )
            .cancelFlow(
                isPresented: $showCancelFlow,
                productId: iapManager.activeSubscription?.productId ?? "",
                userId: authVM.appleUserID ?? "",
                onResult: { result in
                    switch result {
                    case .cancelled, .paused:
                        Task { await iapManager.syncWithSDK(userId: authVM.appleUserID ?? "") }
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
                    accountCard
                    weeklyReflectionCard

                    if let manager = ZeroSettle.shared.migrationManager,
                       manager.state == .eligible || manager.state == .presented,
                       let offer = manager.offerData {
                        migrationBanner(manager: manager, offer: offer)
                    }

                    migrationTipSection

                    subscriptionCard
                    streakSaverCard
                    reminderCard
                    supportSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPremiumUpsell) {
            PremiumUpsellView(onWebCheckout: { webCheckoutProduct = $0 })
        }
        .fullScreenCover(isPresented: $showConsumableShop) {
            ConsumableShopView(onWebCheckout: { webCheckoutProduct = $0 })
        }
        .alert("Purchases Restored", isPresented: $showRestoreConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your purchases have been restored successfully.")
        }
        .checkoutSheet(
            item: $webCheckoutProduct,
            userId: authVM.appleUserID ?? "",
            freeTrialDays: ZeroSettle.shared.migrationManager?.offerData?.freeTrialDays ?? 0,
            preload: .all,
            onPresent: {
                showPremiumUpsell = false
            }
        ) {
            if let product = webCheckoutProduct {
                CheckoutSheetHeader(product: product)
            }
        } onComplete: { result in
            Task {
                errorMessage = await iapManager.processWebCheckout(result, userId: authVM.appleUserID)
                // If this was a migration checkout, track the conversion
                if case .success = result,
                   let manager = ZeroSettle.shared.migrationManager,
                   manager.state == .presented {
                    manager.markCheckoutSucceeded()
                    await manager.showAppleSubscriptionManagement()
                }
            }
        }
        .task {
            guard let userId = authVM.appleUserID else { return }

            // Warm up the active subscription tier's checkout
            if let tier = iapManager.activeSubscription {
                await CheckoutSheet.warmUp(productId: tier.productId, userId: userId)
            }

            // Warm up the migration product's checkout if eligible
            if let productId = ZeroSettle.shared.migrationManager?.offerData?.prompt.productId {
                await CheckoutSheet.warmUp(productId: productId, userId: userId)
            }

            // Check if an upgrade offer is available from the backend
            if iapManager.canUpgradeToAnnual {
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
            if iapManager.isStoreKitBilling {
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
            if iapManager.isStoreKitBilling {
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

    // MARK: - Account Card

    private var accountCard: some View {
        VStack(spacing: 16) {
            Image(systemName: authVM.currentUser?.avatarSystemName ?? "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.premiumGradient)

            VStack(spacing: 4) {
                Text(authVM.currentUser?.displayName ?? "User")
                    .font(.title3.weight(.semibold))

                if let email = authVM.currentUser?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if !habits.isEmpty {
                Divider()

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.justWarning)
                            Text("\(longestStreak)")
                                .font(.title3.weight(.bold))
                        }
                        Text(longestStreak == 1 ? "week streak" : "week streak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 2) {
                        Text("\(consistencyThisMonth)%")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.justPrimary)
                        Text("this month")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
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
                            .foregroundColor(habit.accentColor.color)
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
                manager.present()
                if let product = ZeroSettle.shared.product(for: offer.prompt.productId) {
                    webCheckoutProduct = product
                }
            } label: {
                Text(offer.prompt.ctaText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(LinearGradient.savingsGradient, in: RoundedRectangle(cornerRadius: 12))
            }

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

    // MARK: - Migration Tip (SDK built-in view)

    private var migrationTipSection: some View {
        MigrationTipView(
            userId: authVM.appleUserID ?? "",
            backgroundColor: Color(.secondarySystemGroupedBackground),
            onEvent: { event in
                switch event {
                case .migrationCompleted:
                    Task { await iapManager.syncWithSDK(userId: authVM.appleUserID ?? "") }
                default:
                    break
                }
            }
        )
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let tier = iapManager.activeSubscription {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("JustOne Pro")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(LinearGradient.premiumGradient)
                        }

                        Text("Unlimited streaks")
                            .font(.subheadline)

                        // Show actual price from catalog when on direct billing
                        if !iapManager.isStoreKitBilling,
                           let product = ZeroSettle.shared.product(for: tier.productId),
                           let webPrice = product.webPrice {
                            Text("\(tier.displayName) \u{00B7} \(webPrice.formatted)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(tier.displayName) \u{00B7} \(tier.price)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        if iapManager.isSubscriptionCancelled {
                            Text("Cancelling")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                        } else {
                            Text("Active")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.justSuccess)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.justSuccess.opacity(0.12), in: Capsule())
                        }

                        if !iapManager.isStoreKitBilling {
                            Text("Direct billing")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if iapManager.isSubscriptionCancelled {
                    if let expiresAt = iapManager.subscriptionExpiresAt {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("Your subscription expires \(expiresAt, style: .date)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    if iapManager.canUpgradeToAnnual && isUpgradeAvailable {
                        Button { showAnnualUpgrade = true } label: {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upgrade to Annual")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(LinearGradient.premiumGradient, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    HStack {
                        if !iapManager.isAtHighestTier {
                            Button { showPremiumUpsell = true } label: {
                                Text("Change plan")
                                    .font(.subheadline)
                                    .foregroundColor(.justPrimary)
                            }
                        }

                        Spacer()

                        Button { showCancelFlow = true } label: {
                            Text("Cancel")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Free Plan")
                            .font(.title3.weight(.bold))
                        Text("1 habit limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Text("Upgrade to Pro for unlimited streaks, advanced analytics, and cloud sync (coming soon).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button { showPremiumUpsell = true } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Pro")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(LinearGradient.premiumGradient, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Streak Saver Card

    private var streakSaverCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bandage.fill")
                    .foregroundColor(.justWarning)
                Text("Streak Savers")
                    .font(.headline)
                Spacer()
            }

            Text("Protect a streak if you miss a day")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(iapManager.streakSaverTokens)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.justWarning)
                    Text("tokens available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button { showConsumableShop = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Buy More")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.justWarning, in: Capsule())
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Reminder Card

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.justPrimary)
                Text("Reminders")
                    .font(.headline)
                Spacer()
            }

            Toggle("Daily reminder", isOn: $reminderEnabled)
                .tint(.justPrimary)
                .onChange(of: reminderEnabled) { _, enabled in
                    UserDefaults.standard.set(enabled, forKey: NotificationKeys.reminderEnabled)
                    if enabled {
                        Task { await NotificationManager.shared.requestPermission() }
                    } else {
                        Task { await NotificationManager.shared.cancelReminder() }
                    }
                }

            if reminderEnabled {
                HStack {
                    Text("Reminder time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: reminderTime) { _, newTime in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                        UserDefaults.standard.set(comps.hour ?? 20, forKey: NotificationKeys.reminderHour)
                        UserDefaults.standard.set(comps.minute ?? 0, forKey: NotificationKeys.reminderMinute)
                    }
                }
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
                        try await iapManager.restorePurchases(userId: authVM.appleUserID)
                        showRestoreConfirmation = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Restore Purchases")
                    Spacer()
                    if iapManager.isPurchasing {
                        ProgressView()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(16)
                .glassCard()
            }
            .disabled(iapManager.isPurchasing)

            HStack {
                Spacer()
                VStack(spacing: 2) {
                    if let joined = authVM.currentUser?.joinedAt {
                        Text("Member since \(joined.formatted(.dateTime.month(.wide).year()))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("JustOne v1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Powered by ZeroSettle")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
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
        guard let tier = iapManager.activeSubscription,
              let userId = authVM.appleUserID else { return }
        do {
            try await ZeroSettle.shared.cancelSubscription(
                productId: tier.productId,
                userId: userId
            )
            await iapManager.syncWithSDK(userId: userId)
        } catch {
            errorMessage = "Failed to cancel: \(error.localizedDescription)"
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}
