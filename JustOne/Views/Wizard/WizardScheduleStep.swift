//
//  WizardScheduleStep.swift
//  JustOne
//
//  Step 2 of the Add Habit Wizard: journey setup
//  (value type, start/goal, increment, pacing, weekly goal).
//

import SwiftUI

struct WizardScheduleStep: View {
    @Binding var valueType: JourneyValueType
    @Binding var direction: JourneyDirection
    @Binding var customUnit: String
    @Binding var startValue: Double
    @Binding var goalValue: Double
    @Binding var increment: Double
    @Binding var pacingDays: Int
    @Binding var frequencyPerWeek: Int
    @Binding var startTimeDate: Date
    @Binding var goalTimeDate: Date

    let effectiveColor: Color

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Value type picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("What are you tracking?")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                        spacing: 10
                    ) {
                        ForEach(JourneyValueType.allCases) { type in
                            Button {
                                valueType = type
                                direction = type.defaultDirection
                                applyDefaultValues(for: type)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.iconName)
                                        .font(.title3)
                                    Text(type.displayName)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(valueType == type ? .white : effectiveColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(
                                    valueType == type
                                        ? effectiveColor
                                        : effectiveColor.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                            }
                        }
                    }
                }

                // Custom unit field
                if valueType == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unit Label")
                            .font(.subheadline.weight(.semibold))

                        TextField("e.g., pages, miles", text: $customUnit)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .glassCard(cornerRadius: 14)
                    }
                }

                // Start value
                valueInput(label: "Start Value", value: $startValue, timeDate: $startTimeDate)

                // Goal value
                valueInput(label: "Goal Value", value: $goalValue, timeDate: $goalTimeDate)

                // Direction toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Direction")
                        .font(.subheadline.weight(.semibold))

                    VStack {
                        Picker("Direction", selection: $direction) {
                            Text("Increasing").tag(JourneyDirection.increasing)
                            Text("Decreasing").tag(JourneyDirection.decreasing)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .glassCard()
                }

                // Increment
                incrementInput

                // Pacing days
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days per Level")
                        .font(.subheadline.weight(.semibold))

                    HStack {
                        HStack(spacing: 4) {
                            TextField("", value: $pacingDays, format: .number)
                                .keyboardType(.numberPad)
                                .font(.headline)
                                .monospacedDigit()
                                .fixedSize(horizontal: true, vertical: false)

                            Text("days")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 16) {
                            Button {
                                if pacingDays > 1 { pacingDays -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(pacingDays > 1 ? effectiveColor : .gray.opacity(0.3))
                            }
                            .disabled(pacingDays <= 1)

                            Button {
                                pacingDays += 1
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(effectiveColor)
                            }
                        }
                    }
                    .padding(16)
                    .glassCard()
                }

                // Weekly goal (hidden for frequency-type journeys which derive it from startValue)
                if valueType != .frequency {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly Goal")
                            .font(.subheadline.weight(.semibold))

                        HStack {
                            Text("\(frequencyPerWeek)\u{00D7} per week")
                                .font(.headline)

                            Spacer()

                            HStack(spacing: 16) {
                                Button {
                                    if frequencyPerWeek > 1 { frequencyPerWeek -= 1 }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(frequencyPerWeek > 1 ? effectiveColor : .gray.opacity(0.3))
                                }
                                .disabled(frequencyPerWeek <= 1)

                                Button {
                                    if frequencyPerWeek < 7 { frequencyPerWeek += 1 }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(frequencyPerWeek < 7 ? effectiveColor : .gray.opacity(0.3))
                                }
                                .disabled(frequencyPerWeek >= 7)
                            }
                        }
                        .padding(16)
                        .glassCard()
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Value Input

    @ViewBuilder
    private func valueInput(label: String, value: Binding<Double>, timeDate: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))

            switch valueType {
            case .time:
                timeValueRow(value: value, timeDate: timeDate, label: label)
            case .weight:
                stepperValueRow(value: value, step: increment, unit: "lbs", allowDecimals: true)
            case .duration:
                stepperValueRow(value: value, step: 5, unit: "min", allowDecimals: false)
            case .count:
                stepperValueRow(value: value, step: increment, unit: "", allowDecimals: false)
            case .custom:
                stepperValueRow(value: value, step: increment, unit: customUnit, allowDecimals: true)
            case .frequency:
                stepperValueRow(value: value, step: increment, unit: "\u{00D7}/week", allowDecimals: false)
            }
        }
    }

    private func timeValueRow(value: Binding<Double>, timeDate: Binding<Date>, label: String) -> some View {
        HStack {
            Text(valueType.format(value.wrappedValue))
                .font(.headline)
                .monospacedDigit()

            Spacer()

            DatePicker(
                label,
                selection: timeDate,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .onChange(of: timeDate.wrappedValue) { _, newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                value.wrappedValue = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func stepperValueRow(value: Binding<Double>, step: Double, unit: String, allowDecimals: Bool) -> some View {
        HStack {
            HStack(spacing: 4) {
                TextField(
                    "",
                    value: value,
                    format: .number.precision(.fractionLength(allowDecimals ? 0...2 : 0...0))
                )
                .keyboardType(allowDecimals ? .decimalPad : .numberPad)
                .font(.headline)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - step)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value.wrappedValue > 0 ? effectiveColor : .gray.opacity(0.3))
                }
                .disabled(value.wrappedValue <= 0)

                Button {
                    value.wrappedValue += step
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(effectiveColor)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Increment Input

    private var incrementInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Step Size")
                .font(.subheadline.weight(.semibold))

            HStack {
                HStack(spacing: 4) {
                    TextField(
                        "",
                        value: $increment,
                        format: .number.precision(.fractionLength(allowsDecimals ? 0...2 : 0...0))
                    )
                    .keyboardType(allowsDecimals ? .decimalPad : .numberPad)
                    .font(.headline)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)

                    if !incrementUnit.isEmpty {
                        Text(incrementUnit)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        adjustIncrement(by: -incrementStep)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(increment > incrementStep ? effectiveColor : .gray.opacity(0.3))
                    }
                    .disabled(increment <= incrementStep)

                    Button {
                        adjustIncrement(by: incrementStep)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(effectiveColor)
                    }
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Increment Helpers

    private var incrementUnit: String {
        switch valueType {
        case .time:      return "min"
        case .weight:    return "lbs"
        case .duration:  return "min"
        case .count:     return ""
        case .custom:    return customUnit
        case .frequency: return "\u{00D7}/week"
        }
    }

    private var allowsDecimals: Bool {
        switch valueType {
        case .weight, .custom: return true
        default: return false
        }
    }

    private var incrementStep: Double {
        switch valueType {
        case .time:     return 5
        case .weight:   return 2.5
        case .duration: return 5
        case .count:     return 1
        case .custom:    return 1
        case .frequency: return 1
        }
    }

    private func adjustIncrement(by amount: Double) {
        let newValue = increment + amount
        if newValue > 0 {
            increment = newValue
        }
    }

    // MARK: - Default Values

    private func applyDefaultValues(for type: JourneyValueType) {
        switch type {
        case .time:
            startValue = 480   // 8:00 AM
            goalValue = 360    // 6:00 AM
            increment = 15
            startTimeDate = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
            goalTimeDate = Calendar.current.date(from: DateComponents(hour: 6, minute: 0)) ?? Date()
        case .weight:
            startValue = 50
            goalValue = 100
            increment = 5
        case .duration:
            startValue = 15
            goalValue = 60
            increment = 5
        case .count:
            startValue = 5
            goalValue = 30
            increment = 5
        case .custom:
            startValue = 1
            goalValue = 10
            increment = 1
        case .frequency:
            startValue = 3
            goalValue = 7
            increment = 1
            frequencyPerWeek = Int(startValue)
        }
    }
}
