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
    @Query var existingHabits: [Habit]

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
                case 0:
                    WizardBasicsStep(
                        name: $name,
                        selectedIcon: $selectedIcon,
                        selectedColor: $selectedColor,
                        customColor: $customColor,
                        isCustomColor: $isCustomColor,
                        isInverse: $isInverse,
                        isNameFocused: $isNameFocused,
                        effectiveColor: effectiveColor
                    )
                case 1:
                    WizardScheduleStep(
                        valueType: $valueType,
                        direction: $direction,
                        customUnit: $customUnit,
                        startValue: $startValue,
                        goalValue: $goalValue,
                        increment: $increment,
                        pacingDays: $pacingDays,
                        frequencyPerWeek: $frequencyPerWeek,
                        startTimeDate: $startTimeDate,
                        goalTimeDate: $goalTimeDate,
                        effectiveColor: effectiveColor
                    )
                case 2:
                    WizardReviewStep(
                        name: name,
                        selectedIcon: selectedIcon,
                        effectiveColor: effectiveColor,
                        valueType: valueType,
                        direction: direction,
                        customUnit: customUnit,
                        frequencyPerWeek: frequencyPerWeek,
                        pacingDays: pacingDays,
                        config: buildConfig()
                    )
                default:
                    WizardBasicsStep(
                        name: $name,
                        selectedIcon: $selectedIcon,
                        selectedColor: $selectedColor,
                        customColor: $customColor,
                        isCustomColor: $isCustomColor,
                        isInverse: $isInverse,
                        isNameFocused: $isNameFocused,
                        effectiveColor: effectiveColor
                    )
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

    // MARK: - Helpers

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
            habit.sortOrder = Habit.nextSortOrder(in: existingHabits)
            modelContext.insert(habit)
            dismiss()
        }
    }
}
