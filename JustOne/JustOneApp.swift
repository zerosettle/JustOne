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
        let key = "zs_pk_test_c2f95d4995ab13385b6064d4af428eb7cc3d0218a9754b41"
//        ZeroSettle.baseURLOverride = URL(string: "http://192.168.1.159:8000/v1")
#else
        let key = "zs_pk_live_REPLACE_WITH_PRODUCTION_KEY"
#endif
        ZeroSettle.shared.configure(.init(publishableKey: key))
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
                                AppLogger.iap.info("  \(p.id): storeKit=\(p.storeKitPrice?.formatted ?? "nil"), web=\(p.webPrice?.formatted ?? "nil"), savings=\(p.savingsPercent.map(String.init) ?? "nil")")
                            }
                        } catch {
                            AppLogger.iap.error("Bootstrap failed: \(error)")
                        }
                        await iapManager.syncWithSDK(userId: userId)
                        for product in ZeroSettle.shared.products {
                            await CheckoutSheet.warmUp(productId: product.id, userId: userId)
                        }
                    }
                }
                .zeroSettleHandler()
        }
        .modelContainer(SharedModelContainer.create())
    }
}
