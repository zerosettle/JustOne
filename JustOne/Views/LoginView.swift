//
//  LoginView.swift
//  JustOne
//
//  Branded splash screen with real Sign in with Apple.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient.justBackground
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // MARK: Branding
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.justPrimary.opacity(0.12))
                            .frame(width: 120, height: 120)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(LinearGradient.premiumGradient)
                    }

                    Text("JustOne")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient.premiumGradient)

                    Text("Build one habit at a time.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // MARK: Sign-in CTA
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            authViewModel.handleAuthorization(authorization)
                        case .failure:
                            break
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 54)
                    .cornerRadius(14)

                    Text("Your data stays on your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)
        }
    }
}
