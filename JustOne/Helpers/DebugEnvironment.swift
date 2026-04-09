//
//  DebugEnvironment.swift
//  JustOne
//
//  Debug-only environment switcher for ZeroSettleKit.
//  Allows runtime switching between Production, Staging, and Localhost
//  without rebuilding.
//

#if DEBUG
import Foundation
import ZeroSettleKit

enum DebugServer: String, CaseIterable, Identifiable {
    case production, staging, localhost

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .production: "Production"
        case .staging:    "Staging"
        case .localhost:  "Localhost"
        }
    }
}

enum DebugMode: String, CaseIterable, Identifiable {
    case live, sandbox

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .live:    "Live"
        case .sandbox: "Sandbox"
        }
    }
}

// ZeroSettleKit publishable keys — safe to embed in client code.
// "zs_pk_live_*" → production payment backend
// "zs_pk_test_*" → sandbox/testing backend (no real charges)
enum DebugEnvironment {

    private static let serverKey = "debug_server"
    private static let modeKey   = "debug_mode"

    // MARK: - Current Selection

    static var server: DebugServer {
        get {
            guard let raw = UserDefaults.standard.string(forKey: serverKey),
                  let value = DebugServer(rawValue: raw) else { return .staging }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: serverKey) }
    }

    static var mode: DebugMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: modeKey),
                  let value = DebugMode(rawValue: raw) else { return .sandbox }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modeKey) }
    }

    // MARK: - Key Lookup

    static func apiKey(server: DebugServer, mode: DebugMode) -> String {
        switch (server, mode) {
        case (.production, .live):    return "zs_pk_live_2c44f5c468ff4907322a0f8825e976bce0a7be46571af88b"
        case (.production, .sandbox): return "zs_pk_test_c2f95d4995ab13385b6064d4af428eb7cc3d0218a9754b41"
        case (.staging, .live):       return "TBD"
        case (.staging, .sandbox):    return "zs_pk_test_14084b1fb839050da91618be8c8dca1ff08dc28398a02d2e"
        case (.localhost, .live):     return "zs_pk_live_a7c77a4e93d342b5f480991444f77e4407a40eaa1041b34d"
        case (.localhost, .sandbox):  return "zs_pk_test_b222d1df61e2a564426f5814910841817e317dbbaa277335"
        }
    }

    // MARK: - URL Lookup

    static func baseURL(server: DebugServer) -> URL? {
        switch server {
        case .production: return nil
        case .staging:    return URL(string: "https://api-staging.zerosettle.io/v1")
        case .localhost:  return URL(string: "https://api.zerosettle.ngrok.app/v1")
        }
    }

    // MARK: - Environment Key

    static func envKey(server: DebugServer, mode: DebugMode) -> String {
        "\(server.rawValue)_\(mode.rawValue)"
    }

    static var currentEnvKey: String {
        envKey(server: server, mode: mode)
    }

    // MARK: - Apply

    static func apply() {
        let s = server
        let m = mode
        ZeroSettle.baseURLOverride = baseURL(server: s)
        ZeroSettle.shared.configure(.init(publishableKey: apiKey(server: s, mode: m), preloadCheckout: true))
    }
}
#endif
