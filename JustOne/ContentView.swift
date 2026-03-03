//
//  ContentView.swift
//  JustOne
//
//  Root router: shows LoginView or HomeDashboardView based on auth state.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) var authVM

    var body: some View {
        Group {
            if !authVM.hasRestoredSession {
                // Hold on a blank/branded screen until session restore completes
                ZStack {
                    LinearGradient.justBackground.ignoresSafeArea()
                    ProgressView()
                        .tint(.justPrimary)
                }
            } else if authVM.isAuthenticated {
                HomeDashboardView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authVM.hasRestoredSession)
    }
}
