//
//  HabitLogTodayButton.swift
//  JustOne
//
//  Log-today toggle for both standard and inverse habits.
//

import SwiftUI

struct HabitLogTodayButton: View {
    let habit: Habit
    @Binding var showLevelUp: Bool

    var body: some View {
        if habit.isInverse {
            inverseLogTodayButton
        } else {
            standardLogTodayButton
        }
    }

    // MARK: - Standard

    private var standardLogTodayButton: some View {
        let today = Date()
        let done = habit.isCompleted(on: today)

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                habit.toggleCompletionAndReloadWidget(on: today)
            }
            HapticFeedback.impact(habit.isCompleted(on: today) ? .medium : .light)
            // Check for level-up after completing (not uncompleting)
            if habit.isCompleted(on: today) && habit.qualifiesForLevelUp() {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    showLevelUp = true
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
                Text(done ? "You showed up today" : "Show up today")
                    .font(.headline)
                    .contentTransition(.interpolate)
            }
            .foregroundColor(done ? .white : habit.displayColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                habit.displayColor.opacity(done ? 1.0 : 0.12),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .animation(.easeInOut(duration: 0.25), value: done)
    }

    // MARK: - Inverse

    @ViewBuilder
    private var inverseLogTodayButton: some View {
        let today = Date()
        let affirmed = habit.isAffirmed(on: today)
        let slipped = !habit.isCompleted(on: today) // isCompleted inverts for inverse

        if affirmed {
            // Affirmed state
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    habit.undoAffirmAndReloadWidget(on: today)
                }
                HapticFeedback.impact(.light)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Holding strong!")
                        .font(.headline)
                        .contentTransition(.interpolate)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.justSuccess, in: RoundedRectangle(cornerRadius: 16))
            }
            .animation(.easeInOut(duration: 0.25), value: affirmed)
        } else if slipped {
            // Slipped state
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    habit.undoSlipAndReloadWidget(on: today)
                }
                HapticFeedback.impact(.light)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Slipped today")
                        .font(.headline)
                        .contentTransition(.interpolate)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.justWarning, in: RoundedRectangle(cornerRadius: 16))
            }
            .animation(.easeInOut(duration: 0.25), value: slipped)
        } else {
            // Not interacted — dual buttons
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        habit.affirmDayAndReloadWidget(on: today)
                    }
                    HapticFeedback.impact(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title3)
                        Text("I held strong!")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.justSuccess, in: RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        habit.logSlipAndReloadWidget(on: today)
                    }
                    HapticFeedback.impact(.light)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.title3)
                        Text("I slipped")
                            .font(.headline)
                    }
                    .foregroundColor(.justWarning)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.justWarning.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}
