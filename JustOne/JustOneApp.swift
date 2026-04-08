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

    init() {
        // SDK PATTERN: Configure ZeroSettleKit before any other SDK call.
        // In debug builds, DebugEnvironment handles server/mode selection.
#if DEBUG
        DebugEnvironment.apply()
        ZSOfferManager.resetDismissedState()
#else
        let key = "zs_pk_live_2c44f5c468ff4907322a0f8825e976bce0a7be46571af88b"
        // Each preloaded WebView uses ~3-7 MB; nil = no limit, fine for small catalogs
        ZeroSettle.shared.configure(.init(publishableKey: key, preloadCheckout: false, maxPreloadedWebViews: nil))
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
                .task(id: authViewModel.isAuthenticated) {
                    if authViewModel.isAuthenticated, let userId = authViewModel.appleUserID {
                        do {
                            let name = authViewModel.currentUser?.displayName
                            let email = authViewModel.currentUser?.email
                                ?? name.flatMap { n in
                                    let parts = n.lowercased().split(separator: " ")
                                    return parts.isEmpty || n == "Friend" ? nil : parts.joined(separator: "") + "@gmail.com"
                                }
                            let catalog = try await ZeroSettle.shared.bootstrap(
                                userId: userId,
                                name: name == "Friend" ? nil : name,
                                email: email
                            )
                            AppLogger.iap.info("Bootstrap succeeded — \(catalog.products.count) products")
                            for p in ZeroSettle.shared.products {
                                AppLogger.iap.info("  \(p.id): storeKit=\(p.storeKitPrice?.formatted ?? "nil"), web=\(p.webPrice?.formatted ?? "nil"), savings=\(p.savingsPercent.map(String.init) ?? "nil"), trial=\(p.freeTrialDuration ?? "nil"), trialEligible=\(p.isTrialEligible.map(String.init) ?? "nil")")
                            }
                        } catch {
                            AppLogger.iap.error("Bootstrap failed: \(error)")
                        }
                        purchaseManager.creditNewConsumableTokens()
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
                // SDK PATTERN: .zeroSettleHandler() enables universal-link callbacks
                // for web checkout. Required for the checkout sheet to work.
                .zeroSettleHandler()
        }
        .modelContainer(SharedModelContainer.create())
    }
}
