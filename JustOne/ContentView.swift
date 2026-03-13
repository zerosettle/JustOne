//
//  ContentView.swift
//  JustOne
//
//  Root router: shows LoginView or HomeDashboardView based on auth state.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) var authViewModel

    var body: some View {
        Group {
            if !authViewModel.hasRestoredSession {
                // Hold on a blank/branded screen until session restore completes
                ZStack {
                    LinearGradient.justBackground.ignoresSafeArea()
                    ProgressView()
                        .tint(.justPrimary)
                }
            } else if authViewModel.isAuthenticated {
                HomeDashboardView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.hasRestoredSession)
    }
}
