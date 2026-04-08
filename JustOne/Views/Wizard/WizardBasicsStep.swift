//
//  WizardBasicsStep.swift
//  JustOne
//
//  Step 1 of the Add Habit Wizard: name, icon, color, habit type.
//

import SwiftUI

struct WizardBasicsStep: View {
    @Binding var name: String
    @Binding var selectedIcon: String
    @Binding var selectedColor: HabitAccentColor
    @Binding var customColor: Color
    @Binding var isCustomColor: Bool
    @Binding var isInverse: Bool
    @FocusState.Binding var isNameFocused: Bool

    let effectiveColor: Color

    // MARK: - Icon Options

    private let iconOptions = [
        "star.fill", "dumbbell.fill", "book.fill", "drop.fill",
        "heart.fill", "brain", "figure.walk", "moon.fill",
        "leaf.fill", "cup.and.saucer.fill", "pencil", "music.note"
    ]

    // MARK: - Body

    var body: some View {
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
}
