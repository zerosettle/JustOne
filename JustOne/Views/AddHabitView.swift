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

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor: HabitAccentColor = .purple
    @State private var frequencyPerWeek = 3
    @State private var isInverse = false
    @FocusState private var isNameFocused: Bool

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
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LinearGradient.justBackground)
            .onTapGesture { isNameFocused = false }
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
                .foregroundColor(selectedColor.color)
                .frame(width: 72, height: 72)
                .background(
                    selectedColor.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 20)
                )

            Text(name.isEmpty ? "My New Habit" : name)
                .font(.title3.weight(.semibold))
                .foregroundColor(name.isEmpty ? .secondary : .primary)

            if isInverse {
                Text("Break this habit")
                    .font(.caption)
                    .foregroundColor(selectedColor.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(selectedColor.color.opacity(0.12), in: Capsule())
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
                BreakHabitExplainer(accentColor: selectedColor.color)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func habitTypeOption(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .foregroundColor(isSelected ? .white : selectedColor.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? selectedColor.color : selectedColor.color.opacity(0.10),
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
                            .foregroundColor(icon == selectedIcon ? .white : selectedColor.color)
                            .frame(width: 48, height: 48)
                            .background(
                                icon == selectedIcon
                                    ? selectedColor.color
                                    : selectedColor.color.opacity(0.10),
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
                    Button { selectedColor = color } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if selectedColor == color {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 28, height: 28)
                                }
                            }
                    }
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
                            .foregroundColor(frequencyPerWeek > 1 ? selectedColor.color : .gray.opacity(0.3))
                    }
                    .disabled(frequencyPerWeek <= 1)

                    Button {
                        if frequencyPerWeek < 7 { frequencyPerWeek += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(frequencyPerWeek < 7 ? selectedColor.color : .gray.opacity(0.3))
                    }
                    .disabled(frequencyPerWeek >= 7)
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Notification Permission

    private func requestNotificationPermissionIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: NotificationKeys.hasRequestedPermission) else { return }
        Task {
            await NotificationManager.shared.requestPermission()
        }
    }
}
