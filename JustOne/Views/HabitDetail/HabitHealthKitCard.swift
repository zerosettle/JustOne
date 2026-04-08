//
//  HabitHealthKitCard.swift
//  JustOne
//
//  HealthKit integration card — shows linked trigger or setup prompt.
//

import SwiftUI

struct HabitHealthKitCard: View {
    let habit: Habit
    @State private var showHealthKitSetup = false

    var body: some View {
        if let trigger = habit.healthKitTrigger {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("Health Data")
                        .font(.headline)
                    Spacer()

                    Button {
                        habit.healthKitTrigger = nil
                    } label: {
                        Text("Remove")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: trigger.triggerType.icon)
                        .font(.title3)
                        .foregroundColor(habit.displayColor)
                        .frame(width: 36, height: 36)
                        .background(habit.displayColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-completes at")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if trigger.triggerType == .workout {
                            Text("Any workout")
                                .font(.subheadline.weight(.medium))
                        } else {
                            Text("\(Int(trigger.threshold)) \(trigger.triggerType.unit)")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
            }
            .padding(20)
            .glassCard()
        } else {
            Button {
                showHealthKitSetup = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Link to Health Data")
                            .font(.subheadline.weight(.medium))
                        Text("Auto-complete with steps, workouts, or sleep")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .glassCard()
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showHealthKitSetup) {
                HealthKitSetupSheet(habit: habit)
            }
        }
    }
}
