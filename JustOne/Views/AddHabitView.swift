//
//  AddHabitView.swift
//  JustOne
//
//  Sheet for creating a new standard habit. Includes live preview, icon picker,
//  color picker, a custom frequency stepper, and keyboard dismissal.
//

import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query var existingHabits: [Habit]

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor: HabitAccentColor = .purple
    @State private var customColor: Color = .habitPurple
    @State private var isCustomColor = false
    @State private var frequencyPerWeek = 3
    @State private var isInverse = false
    @State private var healthKitEnabled = false
    @State private var healthKitTriggerType: HealthKitTriggerType = .steps
    @State private var healthKitThreshold: Double = 10_000
    @FocusState private var isNameFocused: Bool

    private var effectiveColor: Color {
        isCustomColor ? customColor : selectedColor.color
    }

    private let iconOptions = [
        "star.fill", "dumbbell.fill", "book.fill", "drop.fill",
        "heart.fill", "brain", "figure.walk", "moon.fill",
        "leaf.fill", "cup.and.saucer.fill", "pencil", "music.note"
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewCard
                    nameField
                    habitTypePicker
                    iconPicker
                    colorPicker
                    if !isInverse {
                        frequencyPicker
                        healthKitSection
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LinearGradient.justBackground)
            .onTapGesture { isNameFocused = false }
            .onChange(of: selectedIcon) { isNameFocused = false }
            .onChange(of: selectedColor) { isNameFocused = false }
            .onChange(of: isInverse) { isNameFocused = false }
            .onChange(of: frequencyPerWeek) { isNameFocused = false }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let habit = Habit(
                            name: name,
                            icon: selectedIcon,
                            accentColor: selectedColor,
                            frequencyPerWeek: isInverse ? 7 : frequencyPerWeek,
                            isInverse: isInverse
                        )
                        if isCustomColor {
                            habit.customColorHex = customColor.toHex()
                        }
                        if healthKitEnabled && !isInverse {
                            let trigger = HealthKitTrigger(triggerType: healthKitTriggerType, threshold: healthKitThreshold)
                            habit.healthKitTrigger = trigger
                            Task { await HealthKitManager.shared.requestAuthorization(for: trigger) }
                        }
                        habit.sortOrder = Habit.nextSortOrder(in: existingHabits)
                        modelContext.insert(habit)
                        requestNotificationPermissionIfNeeded()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedIcon)
                .font(.system(size: 40))
                .foregroundColor(effectiveColor)
                .frame(width: 72, height: 72)
                .background(
                    effectiveColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 20)
                )

            Text(name.isEmpty ? "My New Habit" : name)
                .font(.title3.weight(.semibold))
                .foregroundColor(name.isEmpty ? .secondary : .primary)

            if isInverse {
                Text("Break this habit")
                    .font(.caption)
                    .foregroundColor(effectiveColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(effectiveColor.opacity(0.12), in: Capsule())
            } else {
                Text("\(frequencyPerWeek)\u{00D7} per week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Habit Type Picker

    private var habitTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Habit Type")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                habitTypeOption(
                    title: "Build",
                    subtitle: "Do something",
                    icon: "checkmark.circle",
                    isSelected: !isInverse
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) { isInverse = false }
                }

                habitTypeOption(
                    title: "Break",
                    subtitle: "Stop something",
                    icon: "xmark.circle",
                    isSelected: isInverse
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) { isInverse = true }
                }
            }

            if isInverse {
                BreakHabitExplainer(accentColor: effectiveColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func habitTypeOption(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    // MARK: - Name Field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Habit Name")
                .font(.subheadline.weight(.semibold))

            TextField("e.g., Hit the Gym", text: $name)
                .focused($isNameFocused)
                .textFieldStyle(.plain)
                .padding(16)
                .glassCard(cornerRadius: 14)
        }
    }

    // MARK: - Icon Picker

    private var iconPicker: some View {
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
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
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

    // MARK: - Frequency Picker

    private var frequencyPicker: some View {
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

    // MARK: - HealthKit Section

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $healthKitEnabled.animation(.easeInOut(duration: 0.25))) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("Link to Health Data")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .tint(effectiveColor)

            if healthKitEnabled {
                HealthKitTriggerPicker(
                    triggerType: $healthKitTriggerType,
                    threshold: $healthKitThreshold,
                    accentColor: effectiveColor
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Notification Permission

    private func requestNotificationPermissionIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: NotificationKeys.hasRequestedPermission) else { return }
        Task {
            await NotificationManager.shared.requestPermission()
        }
    }
}
