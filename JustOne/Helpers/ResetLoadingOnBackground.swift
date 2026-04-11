//
//  ResetLoadingOnBackground.swift
//  JustOne
//
//  Shared modifier that resets a loading flag when the app
//  moves to background — prevents stuck loading spinners
//  after returning from browser checkouts or app switches.
//

import SwiftUI

struct ResetLoadingOnBackground: ViewModifier {
    @Binding var isLoading: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            if phase != .active { isLoading = false }
        }
    }
}

extension View {
    func resetLoadingOnBackground(_ isLoading: Binding<Bool>) -> some View {
        modifier(ResetLoadingOnBackground(isLoading: isLoading))
    }
}
