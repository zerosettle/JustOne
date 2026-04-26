//
//  JustOneApp.swift
//  JustOne
//
//  App entry point. Sets up SwiftData model container and injects
//  shared state into the environment.
//

import SwiftUI
import SwiftData
import OSLog
import ZeroSettleKit

@main
struct JustOneApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var purchaseManager = PurchaseManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastSyncDate: Date?

    init() {
        // SDK PATTERN: Configure ZeroSettleKit before any other SDK call.
        // In debug builds, DebugEnvironment handles server/mode selection.
#if DEBUG
        DebugEnvironment.apply()
        ZSOfferManager.resetDismissedState()
#else
        let key = "zs_pk_live_2c44f5c468ff4907322a0f8825e976bce0a7be46571af88b"
        // Each preloaded WebView uses ~3-7 MB; nil = no limit, fine for small catalogs
        ZeroSettle.shared.configure(.init(publishableKey: key, preloadCheckout: true, maxPreloadedWebViews: nil))
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(purchaseManager)
                // SDK PATTERN: Wire up the delegate for checkout lifecycle callbacks.
                .onAppear { ZeroSettle.shared.delegate = purchaseManager }
                .task { await authViewModel.restoreSession() }
                // SDK PATTERN: bootstrap() fetches the product catalog, restores
                // entitlements, and starts the StoreKit transaction listener — all in
                // one call. You do NOT need to call restoreEntitlements() separately.
                // Wait for session restore to complete before bootstrapping.
                // This prevents the race where restoreSession() sets isAuthenticated=true
                // mid-execution, triggering bootstrap, which then gets cancelled when
                // restoreSession() updates other state (isLoading, hasRestoredSession).
                // SDK PATTERN: bootstrapTrigger increments on every sign-in
                // (including account switches), so this task re-fires and
                // re-bootstraps the SDK for the new user.
                .task(id: "\(authViewModel.hasRestoredSession)_\(authViewModel.bootstrapTrigger)") {
                    guard authViewModel.isAuthenticated, authViewModel.hasRestoredSession,
                          let userId = authViewModel.appleUserID else { return }

                    authViewModel.isBootstrapping = true
                    defer { authViewModel.isBootstrapping = false }

                    let name = authViewModel.currentUser?.displayName
                    let email = authViewModel.currentUser?.email
                        ?? name.flatMap { n in
                            let parts = n.lowercased().split(separator: " ")
                            return parts.isEmpty || n == "Friend" ? nil : parts.joined(separator: "") + "@gmail.com"
                        }

                    // Retry up to 3 times — bootstrap can fail transiently
                    // from task cancellation races or server hiccups.
                    for attempt in 1...3 {
                        guard !Task.isCancelled else { return }
                        do {
                            let catalog = try await ZeroSettle.shared.bootstrap(
                                userId: userId,
                                name: name == "Friend" ? nil : name,
                                email: email
                            )
                            AppLogger.iap.info("Bootstrap succeeded — \(catalog.products.count) products")
                            for p in ZeroSettle.shared.products {
                                AppLogger.iap.info("  \(p.id): storeKit=\(p.storeKitPrice?.formatted ?? "nil"), web=\(p.webPrice?.formatted ?? "nil"), savings=\(p.savingsPercent.map(String.init) ?? "nil"), trial=\(p.freeTrialDuration ?? "nil"), trialEligible=\(p.isTrialEligible.map(String.init) ?? "nil")")
                            }
                            purchaseManager.creditNewConsumableTokens()
                            return
                        } catch {
                            AppLogger.iap.error("Bootstrap attempt \(attempt)/3 failed: \(error)")
                            if attempt < 3 {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                            }
                        }
                    }
                }
                // SDK PATTERN: entitlementUpdates stream for real-time sync.
                // Fires on renewals, cancellations, and server-side revocations
                // so the UI stays current without polling.
                .task {
                    for await _ in ZeroSettle.shared.entitlementUpdates {
                        purchaseManager.creditNewConsumableTokens()
                    }
                }
                // SDK PATTERN: Sync entitlements when returning to foreground.
                // Catches subscription state changes and browser checkout completions.
                // Debounced to avoid redundant API calls on rapid app switches.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, authViewModel.isAuthenticated, let userId = authViewModel.appleUserID {
                        let now = Date()
                        if lastSyncDate == nil || now.timeIntervalSince(lastSyncDate!) > 30 {
                            lastSyncDate = now
                            Task { await purchaseManager.syncWithSDK(userId: userId) }
                        }
                    }
                }
                // SDK PATTERN: .zeroSettleHandler() enables universal-link callbacks
                // for web checkout. Required for the checkout sheet to work.
                .zeroSettleHandler()
        }
        .modelContainer(SharedModelContainer.create())
    }
}
