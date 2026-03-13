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
    @State private var authVM = AuthViewModel()
    @State private var iapManager = ZeroSettleManager()

    init() {
#if DEBUG
        DebugEnvironment.apply()
#else
        let key = "zs_pk_live_2c44f5c468ff4907322a0f8825e976bce0a7be46571af88b"
        ZeroSettle.shared.configure(.init(publishableKey: key, preloadCheckout: true))
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authVM)
                .environment(iapManager)
                .task { await authVM.restoreSession() }
                .task(id: authVM.isAuthenticated) {
                    if authVM.isAuthenticated, let userId = authVM.appleUserID {
                        do {
                            let catalog = try await ZeroSettle.shared.bootstrap(userId: userId)
                            AppLogger.iap.info("Bootstrap succeeded — \(catalog.products.count) products")
                            for p in ZeroSettle.shared.products {
                                AppLogger.iap.info("  \(p.id): storeKit=\(p.storeKitPrice?.formatted ?? "nil"), web=\(p.webPrice?.formatted ?? "nil"), savings=\(p.savingsPercent.map(String.init) ?? "nil"), trial=\(p.freeTrialDuration ?? "nil"), trialEligible=\(p.isTrialEligible.map(String.init) ?? "nil")")
                            }
                        } catch {
                            AppLogger.iap.error("Bootstrap failed: \(error)")
                        }
                        // Bootstrap already calls restoreEntitlements() internally —
                        // just credit any new consumable tokens from the results.
                        iapManager.creditNewConsumableTokens()
                    }
                }
                .task {
                    // Listen for real-time entitlement changes (renewals, cancellations,
                    // server-side revocations) so the UI stays in sync automatically.
                    for await _ in ZeroSettle.shared.entitlementUpdates {
                        iapManager.creditNewConsumableTokens()
                    }
                }
                .zeroSettleHandler()
        }
        .modelContainer(SharedModelContainer.create())
    }
}
