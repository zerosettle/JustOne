//
//  AuthViewModel.swift
//  JustOne
//
//  Real Sign in with Apple authentication.
//  Stores the Apple user ID in Keychain (persists across reinstalls)
//  and user profile in UserDefaults.
//

import SwiftUI
import AuthenticationServices
import ZeroSettleKit

@MainActor
@Observable
final class AuthViewModel {
    private(set) var currentUser: User?
    private(set) var isAuthenticated = false
    private(set) var isLoading = false
    private(set) var hasRestoredSession = false
    /// Incremented on every sign-in (including account switches) so the
    /// `.task(id:)` in JustOneApp re-fires and re-bootstraps the SDK.
    private(set) var bootstrapTrigger: Int = 0

    private static let appleUserIDKey = "appleUserID"
    private static let userDefaultsKey = "storedUser"
    #if DEBUG
    private static let debugAccountKey = "isDebugAccount"
    #endif

    /// The stable Apple user ID from Keychain (persists across reinstalls).
    /// Used as the ZeroSettle SDK user identifier.
    var appleUserID: String? {
        guard let data = KeychainHelper.read(for: Self.appleUserIDKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Session Restoration

    /// Reads the stored Apple user ID from Keychain, verifies credential
    /// state with Apple, and restores the session if still authorized.
    func restoreSession() async {
        guard let data = KeychainHelper.read(for: Self.appleUserIDKey),
              let userID = String(data: data, encoding: .utf8) else {
            hasRestoredSession = true
            return
        }

        isLoading = true

        #if DEBUG
        // Debug accounts use synthetic UUIDs that Apple won't recognize.
        // Skip credential verification and restore directly from UserDefaults.
        if isDebugAccount(userID), let user = loadUserFromDefaults() {
            currentUser = user
            isAuthenticated = true
            isLoading = false
            hasRestoredSession = true
            return
        }
        #endif

        let state: ASAuthorizationAppleIDProvider.CredentialState = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { credentialState, _ in
                continuation.resume(returning: credentialState)
            }
        }

        if state == .authorized, let user = loadUserFromDefaults() {
            currentUser = user
            isAuthenticated = true
        }

        isLoading = false
        hasRestoredSession = true
    }

    // MARK: - Handle Authorization

    /// Processes the ASAuthorization result from SignInWithAppleButton.
    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userID = credential.user

        // Persist Apple user ID in Keychain
        if let data = userID.data(using: .utf8) {
            KeychainHelper.save(data, for: Self.appleUserIDKey)
        }
        #if DEBUG
        UserDefaults.standard.set(false, forKey: Self.debugAccountKey)
        #endif

        // Apple only sends name/email on the FIRST authorization
        let existingUser = loadUserFromDefaults()

        let displayName: String
        if let fullName = credential.fullName,
           let given = fullName.givenName {
            let family = fullName.familyName.map { " \($0)" } ?? ""
            displayName = given + family
        } else {
            displayName = existingUser?.displayName ?? "Friend"
        }

        let email = credential.email ?? existingUser?.email

        let user = User(
            id: existingUser?.id ?? UUID(),
            displayName: displayName,
            email: email,
            avatarSystemName: "person.crop.circle.fill",
            joinedAt: existingUser?.joinedAt ?? Date()
        )

        saveUserToDefaults(user)
        currentUser = user
        isAuthenticated = true
        bootstrapTrigger += 1
    }

    // MARK: - Sign Out

    func signOut() {
        ZeroSettle.shared.logout()
        KeychainHelper.delete(for: Self.appleUserIDKey)
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - UserDefaults Persistence

    private func saveUserToDefaults(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    private func loadUserFromDefaults() -> User? {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
}

// MARK: - Debug Account Switching

#if DEBUG
extension AuthViewModel {
    private func isDebugAccount(_ userID: String) -> Bool {
        UserDefaults.standard.bool(forKey: Self.debugAccountKey)
    }

    /// Signs in with a synthetic user ID (bypasses Sign in with Apple).
    /// Returns the new userId so callers can re-bootstrap.
    @discardableResult
    func debugSignIn(userId: String, label: String) -> String {
        if let data = userId.data(using: .utf8) {
            KeychainHelper.save(data, for: Self.appleUserIDKey)
        }
        UserDefaults.standard.set(true, forKey: Self.debugAccountKey)

        let existing = loadUserFromDefaults()
        let user = User(
            id: existing?.id ?? UUID(),
            displayName: label,
            email: nil,
            avatarSystemName: "person.crop.circle.fill",
            joinedAt: existing?.joinedAt ?? Date()
        )
        saveUserToDefaults(user)
        currentUser = user
        isAuthenticated = true
        bootstrapTrigger += 1
        return userId
    }
}
#endif
