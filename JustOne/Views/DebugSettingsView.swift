//
//  DebugSettingsView.swift
//  JustOne
//
//  Debug-only view for switching ZeroSettleKit environments at runtime
//  and managing synthetic test accounts.
//

#if DEBUG
import SwiftUI
import ZeroSettleKit

// MARK: - Debug Account Model

struct DebugAccount: Codable, Identifiable, Equatable {
    let id: String          // synthetic userId (UUID string)
    var label: String
    let createdAt: Date
}

private enum DebugAccountStore {
    private static let key = "debug_accounts"

    static var all: [DebugAccount] {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
            return (try? JSONDecoder().decode([DebugAccount].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }

    static func add(_ account: DebugAccount) {
        var list = all
        list.append(account)
        all = list
    }

    static func remove(id: String) {
        all = all.filter { $0.id != id }
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

    @State private var accounts: [DebugAccount] = DebugAccountStore.all
    @State private var newAccountLabel = ""

    private var resolvedKey: String {
        DebugEnvironment.apiKey(server: selectedServer, mode: selectedMode)
    }

    private var resolvedURL: String {
        DebugEnvironment.baseURL(server: selectedServer)?.absoluteString ?? "SDK default"
    }

    private var activeUserId: String? { authViewModel.appleUserID }

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
                    Task { await applyAndRebootstrap() }
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

            Section("Test Accounts") {
                if accounts.isEmpty {
                    Text("No test accounts yet.")
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
                            Text(account.id.prefix(12) + "...")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
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
                    accounts = DebugAccountStore.all
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
    }

    // MARK: - Actions

    private func applyAndRebootstrap() async {
        isApplying = true
        statusMessage = nil
        defer { isApplying = false }

        DebugEnvironment.server = selectedServer
        DebugEnvironment.mode = selectedMode
        DebugEnvironment.apply()

        guard let userId = authViewModel.appleUserID else {
            statusMessage = "Configured (no user — skipped bootstrap)"
            return
        }

        do {
            let catalog = try await ZeroSettle.shared.bootstrap(userId: userId)
            purchaseManager.creditNewConsumableTokens()
            statusMessage = "Switched — \(catalog.products.count) products loaded"
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    private func createAccount() {
        let account = DebugAccount(
            id: UUID().uuidString,
            label: newAccountLabel.trimmingCharacters(in: .whitespaces),
            createdAt: Date()
        )
        DebugAccountStore.add(account)
        accounts = DebugAccountStore.all
        newAccountLabel = ""

        // Auto-switch to the new account
        switchTo(account)
    }

    private func switchTo(_ account: DebugAccount) {
        authViewModel.debugSignIn(userId: account.id, label: account.label)
        statusMessage = nil
        // isAuthenticated change triggers bootstrap in JustOneApp
    }
}
#endif
