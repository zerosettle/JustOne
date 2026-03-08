//
//  AddHabitWizardView.swift
//  JustOne
//
//  3-step paged wizard for creating Progressive Journey habits.
//  Step 1: Basics (name, icon, color, frequency)
//  Step 2: Journey setup (value type, start, goal, increment, pacing)
//  Step 3: Review and create
//

import SwiftUI
import SwiftData
import UIKit

struct AddHabitWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    // Edit mode: pre-populate from existing habit
    var editingHabit: Habit? = nil
    var onSave: ((JourneyConfig) -> Void)? = nil

    // MARK: - Step Navigation

    @State private var currentStep = 0
    @State private var isGoingForward = true
    private let totalSteps = 3

    // MARK: - Step 1: Basics

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor: HabitAccentColor = .purple
    @State private var customColor: Color = .habitPurple
    @State private var isCustomColor = false
    @State private var frequencyPerWeek = 7
    @State private var isInverse = false
    @FocusState private var isNameFocused: Bool

    private var effectiveColor: Color {
        isCustomColor ? customColor : selectedColor.color
    }

    private let iconOptions = [
        "star.fill", "dumbbell.fill", "book.fill", "drop.fill",
        "heart.fill", "brain", "figure.walk", "moon.fill",
        "leaf.fill", "cup.and.saucer.fill", "pencil", "music.note"
    ]

    // MARK: - Step 2: Journey Setup

    @State private var valueType: JourneyValueType = .time
    @State private var direction: JourneyDirection = .decreasing
    @State private var customUnit = ""
    @State private var startValue: Double = 480  // 8:00 AM
    @State private var goalValue: Double = 360   // 6:00 AM
    @State private var increment: Double = 15
    @State private var pacingDays: Int = 14

    // Time picker helpers
    @State private var startTimeDate = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var goalTimeDate = Calendar.current.date(from: DateComponents(hour: 6, minute: 0)) ?? Date()

    private var isEditing: Bool { editingHabit != nil }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Paged content with edge fades (Messages-style)
            Group {
                switch currentStep {
                case 0: step1Basics
                case 1: step2JourneySetup
                case 2: step3Review
                default: step1Basics
                }
            }
            .id(currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: isGoingForward ? .trailing : .leading),
                removal: .move(edge: isGoingForward ? .leading : .trailing)
            ))
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                backButton
                Spacer()
                forwardButton
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: selectedIcon) { isNameFocused = false }
        .onChange(of: selectedColor) { isNameFocused = false }
        .onChange(of: isInverse) { isNameFocused = false }
        .onChange(of: frequencyPerWeek) { isNameFocused = false }
        .onChange(of: customColor) { isNameFocused = false }
        .onAppear { populateFromEditingHabit() }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? effectiveColor : Color.secondary.opacity(0.2))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    // MARK: - Toolbar Buttons

    @ViewBuilder
    private var backButton: some View {
        if currentStep > 0 {
            Button("Back", systemImage: "chevron.left") {
                isGoingForward = false
                withAnimation { currentStep -= 1 }
            }
        }
    }

    @ViewBuilder
    private var forwardButton: some View {
        if currentStep == totalSteps - 1 {
            Button(isEditing ? "Save" : "Create", systemImage: "checkmark") {
                createOrSaveJourney()
            }
            .tint(effectiveColor)
        } else {
            Button("Next", systemImage: "chevron.right") {
                syncTimeValues()
                isGoingForward = true
                withAnimation { currentStep += 1 }
            }
            .disabled(!canAdvance)
            .tint(canAdvance ? effectiveColor : nil)
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            if valueType == .custom && customUnit.trimmingCharacters(in: .whitespaces).isEmpty {
                return false
            }
            return increment > 0 && startValue != goalValue
        case 2: return true
        default: return false
        }
    }

    // MARK: - Step 1: Basics

    private var step1Basics: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Preview card
                VStack(spacing: 12) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 40))
                        .foregroundColor(effectiveColor)
                        .frame(width: 72, height: 72)
                        .background(
                            effectiveColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 20)
                        )

                    Text(name.isEmpty ? "My Journey" : name)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(name.isEmpty ? .secondary : .primary)

                    Text("Progressive Journey")
                        .font(.caption)
                        .foregroundColor(effectiveColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(effectiveColor.opacity(0.12), in: Capsule())
                }
                .padding(24)
                .frame(maxWidth: .infinity)

                // Habit type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit Type")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 12) {
                        wizardTypeOption(title: "Build", subtitle: "Do something", icon: "checkmark.circle", isSelected: !isInverse) {
                            withAnimation(.easeInOut(duration: 0.25)) { isInverse = false }
                        }
                        wizardTypeOption(title: "Break", subtitle: "Stop something", icon: "xmark.circle", isSelected: isInverse) {
                            withAnimation(.easeInOut(duration: 0.25)) { isInverse = true }
                        }
                    }

                    if isInverse {
                        BreakHabitExplainer(accentColor: effectiveColor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit Name")
                        .font(.subheadline.weight(.semibold))

                    TextField("e.g., Wake Up Earlier", text: $name)
                        .focused($isNameFocused)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .glassCard(cornerRadius: 14)
                }

                // Icon picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.subheadline.weight(.semibold))

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                        spacing: 10
                    ) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button { selectedIcon = icon } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundColor(icon == selectedIcon ? .white : effectiveColor)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        icon == selectedIcon
                                            ? effectiveColor
                                            : effectiveColor.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                            }
                        }
                    }
                    .padding(16)
                    .glassCard()
                }

                // Color picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 12) {
                        ForEach(HabitAccentColor.allCases) { color in
                            Button {
                                selectedColor = color
                                isCustomColor = false
                            } label: {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if !isCustomColor && selectedColor == color {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                                .frame(width: 28, height: 28)
                                        }
                                    }
                            }
                        }

                        ColorPicker("", selection: $customColor, supportsOpacity: false)
                            .labelsHidden()
                            .frame(width: 36, height: 36)
                            .overlay {
                                if isCustomColor {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 28, height: 28)
                                }
                            }
                            .onChange(of: customColor) {
                                isCustomColor = true
                                isNameFocused = false
                            }

                        Spacer()
                    }
                    .padding(16)
                    .glassCard()
                }

            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2: Journey Setup

    private var step2JourneySetup: some View {
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

    // MARK: - Step 3: Review

    private var step3Review: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Journey summary card
                VStack(spacing: 16) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 36))
                        .foregroundColor(effectiveColor)
                        .frame(width: 64, height: 64)
                        .background(
                            effectiveColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 18)
                        )

                    Text(name)
                        .font(.title3.weight(.bold))

                    let config = buildConfig()
                    let milestoneCount = config.milestones.count

                    Text("Your journey has \(milestoneCount) level\(milestoneCount == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(effectiveColor)

                    // Milestone preview
                    JourneyTimelineView(
                        journeyConfig: config,
                        accentColor: effectiveColor
                    )
                    .padding(.vertical, 8)

                    // Summary text
                    VStack(spacing: 4) {
                        Text("Start at \(config.formattedValue(config.startValue))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Work toward \(config.formattedValue(config.goalValue))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Stepping by \(config.formattedValue(config.increment)) every \(pacingDays) days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassCard()

                // Details card
                VStack(alignment: .leading, spacing: 12) {
                    detailRow(label: "Type", value: valueType.displayName)
                    detailRow(label: "Direction", value: direction.displayName)
                    detailRow(label: "Frequency", value: "\(frequencyPerWeek)\u{00D7} per week")
                    if valueType == .custom {
                        detailRow(label: "Unit", value: customUnit)
                    }
                }
                .padding(20)
                .glassCard()
            }
            .padding(20)
            .padding(.bottom, 20)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    // MARK: - Helpers

    private func wizardTypeOption(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "\(icon).fill" : icon)
                        .font(.subheadline)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .foregroundColor(isSelected ? .white : effectiveColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? effectiveColor : effectiveColor.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }

    private func buildConfig() -> JourneyConfig {
        JourneyConfig(
            valueType: valueType,
            direction: direction,
            customUnit: customUnit,
            startValue: startValue,
            goalValue: goalValue,
            increment: increment,
            pacingDays: pacingDays
        )
    }

    private func syncTimeValues() {
        if valueType == .time {
            let startComps = Calendar.current.dateComponents([.hour, .minute], from: startTimeDate)
            startValue = Double((startComps.hour ?? 0) * 60 + (startComps.minute ?? 0))

            let goalComps = Calendar.current.dateComponents([.hour, .minute], from: goalTimeDate)
            goalValue = Double((goalComps.hour ?? 0) * 60 + (goalComps.minute ?? 0))
        }
    }

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

    private func populateFromEditingHabit() {
        guard let habit = editingHabit, let config = habit.journeyConfig else { return }
        name = habit.name
        selectedIcon = habit.icon
        selectedColor = habit.accentColor
        frequencyPerWeek = habit.frequencyPerWeek
        valueType = config.valueType
        direction = config.direction
        customUnit = config.customUnit
        startValue = config.startValue
        goalValue = config.goalValue
        increment = config.increment
        pacingDays = config.pacingDays

        if config.valueType == .time {
            let startHour = Int(config.startValue) / 60
            let startMin = Int(config.startValue) % 60
            startTimeDate = Calendar.current.date(from: DateComponents(hour: startHour, minute: startMin)) ?? Date()
            let goalHour = Int(config.goalValue) / 60
            let goalMin = Int(config.goalValue) % 60
            goalTimeDate = Calendar.current.date(from: DateComponents(hour: goalHour, minute: goalMin)) ?? Date()
        }
    }

    private func createOrSaveJourney() {
        syncTimeValues()
        if valueType == .frequency {
            frequencyPerWeek = Int(startValue)
        }
        let config = buildConfig()

        if let onSave = onSave {
            // Edit mode: pass config back
            onSave(config)
            dismiss()
        } else {
            // Create mode: insert new habit
            let habit = Habit(
                name: name,
                icon: selectedIcon,
                accentColor: selectedColor,
                frequencyPerWeek: isInverse ? 7 : frequencyPerWeek,
                journeyConfig: config,
                isInverse: isInverse
            )
            if isCustomColor {
                habit.customColorHex = customColor.toHex()
            }
            modelContext.insert(habit)
            dismiss()
        }
    }
}
