//
//  HealthKitTriggerPicker.swift
//  JustOne
//
//  Reusable grid picker for selecting a HealthKit trigger type
//  and configuring its threshold. Used by AddHabitView and HealthKitSetupSheet.
//

import SwiftUI

struct HealthKitTriggerPicker: View {
    @Binding var triggerType: HealthKitTriggerType
    @Binding var threshold: Double
    var accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(HealthKitTriggerType.allCases) { type in
                    Button {
                        triggerType = type
                        threshold = type.defaultThreshold
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.title3)
                            Text(type.displayName)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(triggerType == type ? .white : accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            triggerType == type
                                ? accentColor
                                : accentColor.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                }
            }

            if triggerType.hasConfigurableThreshold {
                HStack {
                    Text("Threshold")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    HStack(spacing: 4) {
                        TextField(
                            "",
                            value: $threshold,
                            format: .number.precision(.fractionLength(0...0))
                        )
                        .keyboardType(.numberPad)
                        .font(.headline)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                        .multilineTextAlignment(.trailing)

                        if !triggerType.unit.isEmpty {
                            Text(triggerType.unit)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .glassCard(cornerRadius: 12)
            }
        }
    }
}
