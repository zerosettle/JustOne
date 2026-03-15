//
//  HealthKitSetupSheet.swift
//  JustOne
//
//  Bottom sheet for configuring a HealthKit trigger on an existing habit.
//

import SwiftUI

struct HealthKitSetupSheet: View {
    let habit: Habit
    @Environment(\.dismiss) var dismiss

    @State private var triggerType: HealthKitTriggerType = .steps
    @State private var threshold: Double = 10_000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Trigger type picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity Type")
                            .font(.subheadline.weight(.semibold))

                        HealthKitTriggerPicker(
                            triggerType: $triggerType,
                            threshold: $threshold,
                            accentColor: habit.displayColor
                        )
                    }

                    // Description
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text(descriptionText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 12)
                }
                .padding(20)
            }
            .background(LinearGradient.justBackground)
            .navigationTitle("Link Health Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trigger = HealthKitTrigger(triggerType: triggerType, threshold: threshold)
                        habit.healthKitTrigger = trigger
                        Task { await HealthKitManager.shared.requestAuthorization(for: trigger) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var descriptionText: String {
        switch triggerType {
        case .steps:
            return "Auto-completes when your daily step count reaches \(Int(threshold)) steps."
        case .workout:
            return "Auto-completes when you record any workout today."
        case .sleep:
            return "Auto-completes when you get at least \(Int(threshold)) hours of sleep."
        case .mindfulMinutes:
            return "Auto-completes when you log at least \(Int(threshold)) minutes of mindfulness."
        }
    }
}
