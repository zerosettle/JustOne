//
//  HomeAddButton.swift
//  JustOne
//
//  Floating "+" menu button for creating new habits.
//

import SwiftUI

struct HomeAddButton: View {
    let habitCount: Int
    @Binding var showAddStandard: Bool
    @Binding var showAddJourney: Bool
    @Binding var showPremiumUpsell: Bool
    @Environment(PurchaseManager.self) private var purchaseManager

    var body: some View {
        Menu {
            Button {
                handleAddTapped(journey: false)
            } label: {
                Label("Standard Habit", systemImage: "checkmark.circle")
            }

            Button {
                handleAddTapped(journey: true)
            } label: {
                Label("Progressive Journey", systemImage: "chart.line.uptrend.xyaxis")
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .modifier(GlassEffectModifier(tint: Color.justPrimary.opacity(0.8), shape: .circle))
        }
        .accessibilityLabel("Add new habit")
    }

    private func handleAddTapped(journey: Bool) {
        guard purchaseManager.canCreateHabit(currentHabitCount: habitCount) else {
            showPremiumUpsell = true
            return
        }
        if journey {
            showAddJourney = true
        } else {
            showAddStandard = true
        }
    }
}
