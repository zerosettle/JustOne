//
//  DebugSettingsView.swift
//  JustOne
//
//  Debug-only view for switching ZeroSettleKit environments at runtime
//  and managing synthetic test accounts sandboxed per environment.
//

#if DEBUG
import SwiftUI
import ZeroSettleKit

// MARK: - Debug Account Model

struct DebugAccount: Codable, Identifiable, Equatable {
    let id: String          // synthetic userId (UUID string)
    var label: String
    let createdAt: Date
    var envKey: String       // e.g. "staging_sandbox"

    init(id: String, label: String, createdAt: Date, envKey: String) {
        self.id = id
        self.label = label
        self.createdAt = createdAt
        self.envKey = envKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        envKey = try container.decodeIfPresent(String.self, forKey: .envKey) ?? "staging_sandbox"
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, createdAt, envKey
    }
}

private enum DebugAccountStore {
    private static let accountsKey = "debug_accounts"
    private static let lastActiveKey = "debug_lastActiveAccount"

    // MARK: - All Accounts

    static var all: [DebugAccount] {
        get {
            guard let data = UserDefaults.standard.data(forKey: accountsKey) else { return [] }
            return (try? JSONDecoder().decode([DebugAccount].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: accountsKey)
            }
        }
    }

    // MARK: - Per-Environment Filtering

    static func accounts(for envKey: String) -> [DebugAccount] {
        all.filter { $0.envKey == envKey }
    }

    static func add(_ account: DebugAccount) {
        var list = all
        list.append(account)
        all = list
    }

    static func remove(id: String) {
        all = all.filter { $0.id != id }
        // Clean up last-active if the deleted account was last-active in any env
        var lastActive = lastActiveMap
        for (env, activeId) in lastActive where activeId == id {
            lastActive.removeValue(forKey: env)
        }
        saveLastActiveMap(lastActive)
    }

    // MARK: - Last-Active Tracking

    private static var lastActiveMap: [String: String] {
        UserDefaults.standard.dictionary(forKey: lastActiveKey) as? [String: String] ?? [:]
    }

    private static func saveLastActiveMap(_ map: [String: String]) {
        UserDefaults.standard.set(map, forKey: lastActiveKey)
    }

    static func lastActiveAccount(for envKey: String) -> String? {
        lastActiveMap[envKey]
    }

    static func setLastActive(accountId: String, for envKey: String) {
        var map = lastActiveMap
        map[envKey] = accountId
        saveLastActiveMap(map)
    }
}

// MARK: - View

struct DebugSettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PurchaseManager.self) private var purchaseManager

    @State private var selectedServer = DebugEnvironment.server
    @State private var selectedMode   = DebugEnvironment.mode
    @State private var isApplying = false
    @State private var statusMessage: String?

    @State private var accounts: [DebugAccount] = []
    @State private var newAccountLabel = ""

    private var selectedEnvKey: String {
        DebugEnvironment.envKey(server: selectedServer, mode: selectedMode)
    }

    private var resolvedKey: String {
        DebugEnvironment.apiKey(server: selectedServer, mode: selectedMode)
    }

    private var resolvedURL: String {
        DebugEnvironment.baseURL(server: selectedServer)?.absoluteString ?? "SDK default"
    }

    private var activeUserId: String? { authViewModel.appleUserID }

    private var envDisplayName: String {
        "\(selectedServer.displayName) \(selectedMode.displayName)"
    }

    var body: some View {
        Form {
            // MARK: Environment

            Section("Server") {
                Picker("Server", selection: $selectedServer) {
                    ForEach(DebugServer.allCases) { server in
                        Text(server.displayName).tag(server)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Mode") {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(DebugMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Resolved Configuration") {
                LabeledContent("Base URL") {
                    Text(resolvedURL)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }

                LabeledContent("API Key") {
                    Text(String(resolvedKey.prefix(20)) + "...")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button {
                    applyAndRebootstrap()
                } label: {
                    HStack {
                        Spacer()
                        if isApplying {
                            ProgressView()
                        } else {
                            Text("Apply")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isApplying)

                if let statusMessage {
                    HStack {
                        Image(systemName: statusMessage.hasPrefix("Error")
                              ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(statusMessage.hasPrefix("Error") ? .red : .green)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: Accounts

            Section("Test Accounts — \(envDisplayName)") {
                if accounts.isEmpty {
                    Text("No test accounts for this environment.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(accounts) { account in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(account.label)
                                    .font(.subheadline.weight(.medium))
                                if account.id == activeUserId {
                                    Text("ACTIVE")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.15), in: Capsule())
                                }
                            }
                            Text("ZS: " + account.id)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }

                        Spacer()

                        if account.id != activeUserId {
                            Button("Switch") {
                                switchTo(account)
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .onDelete { indexSet in
                    let toRemove = indexSet.map { accounts[$0].id }
                    for id in toRemove { DebugAccountStore.remove(id: id) }
                    accounts = DebugAccountStore.accounts(for: selectedEnvKey)
                }

                HStack {
                    TextField("Account label", text: $newAccountLabel)
                        .font(.subheadline)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        createAccount()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .disabled(newAccountLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if activeUserId != nil {
                Section {
                    LabeledContent("Active User ID") {
                        Text(activeUserId ?? "—")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Debug Environment")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            accounts = DebugAccountStore.accounts(for: selectedEnvKey)
        }
        .onChange(of: selectedServer) {
            accounts = DebugAccountStore.accounts(for: selectedEnvKey)
        }
        .onChange(of: selectedMode) {
            accounts = DebugAccountStore.accounts(for: selectedEnvKey)
        }
    }

    // MARK: - Actions

    private func applyAndRebootstrap() {
        isApplying = true
        statusMessage = nil
        defer { isApplying = false }

        let oldEnvKey = DebugEnvironment.currentEnvKey

        // 1. Save last-active account for the OLD env
        if let userId = authViewModel.appleUserID {
            DebugAccountStore.setLastActive(accountId: userId, for: oldEnvKey)
        }

        // 2. Sign out — clears Keychain + UserDefaults, sets isAuthenticated = false
        authViewModel.signOut()

        // 3. Reset purchase state — zeros tokens/known entitlements
        purchaseManager.debugReset()

        // 4. Persist new server/mode and reconfigure SDK
        DebugEnvironment.server = selectedServer
        DebugEnvironment.mode = selectedMode
        DebugEnvironment.apply()

        let newEnvKey = DebugEnvironment.currentEnvKey

        // 5. Refresh account list for new env
        accounts = DebugAccountStore.accounts(for: newEnvKey)

        // 6. Look up last-active account for new env and sign in.
        //    debugSignIn() bumps bootstrapTrigger, which re-fires the
        //    .task(id:) in JustOneApp and bootstraps the SDK automatically.
        if let lastActiveId = DebugAccountStore.lastActiveAccount(for: newEnvKey),
           let account = accounts.first(where: { $0.id == lastActiveId }) {
            authViewModel.debugSignIn(userId: account.id, label: account.label)
            statusMessage = "Restored \(account.label) — bootstrapping…"
        } else {
            statusMessage = "Switched to \(envDisplayName) — signed out"
        }
    }

    private func createAccount() {
        let account = DebugAccount(
            id: UUID().uuidString,
            label: newAccountLabel.trimmingCharacters(in: .whitespaces),
            createdAt: Date(),
            envKey: DebugEnvironment.currentEnvKey
        )
        DebugAccountStore.add(account)
        accounts = DebugAccountStore.accounts(for: selectedEnvKey)
        newAccountLabel = ""

        // Auto-switch to the new account
        switchTo(account)
    }

    private func switchTo(_ account: DebugAccount) {
        // Clear old account's purchase state before signing into the new one
        purchaseManager.debugReset()
        ZeroSettle.shared.logout()

        DebugAccountStore.setLastActive(accountId: account.id, for: DebugEnvironment.currentEnvKey)
        // debugSignIn() bumps bootstrapTrigger → .task(id:) in JustOneApp
        // re-fires and bootstraps the SDK for the new user automatically.
        authViewModel.debugSignIn(userId: account.id, label: account.label)
        statusMessage = "Switching…"
    }
}
#endif
