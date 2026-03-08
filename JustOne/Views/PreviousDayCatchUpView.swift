//
//  PreviousDayCatchUpView.swift
//  JustOne
//
//  Sheet shown on the first app open of a new day (Pro only).
//  Lets the user mark completions for habits they missed logging yesterday.
//

import SwiftUI
import WidgetKit

struct PreviousDayCatchUpView: View {
    let habits: [Habit]
    @Environment(\.dismiss) private var dismiss

    private let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

    /// Habits that were not completed yesterday.
    private var incompleteHabits: [Habit] {
        habits.filter { !$0.isCompleted(on: yesterday) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.justBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 40))
                                .foregroundColor(.justPrimary)

                            Text("Update Yesterday")
                                .font(.title3.weight(.bold))

                            Text("Did you complete any of these habits yesterday?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        // Habit toggles
                        VStack(spacing: 12) {
                            ForEach(incompleteHabits) { habit in
                                CatchUpRow(habit: habit, date: yesterday)
                            }
                        }

                        if incompleteHabits.isEmpty {
                            Text("You completed everything yesterday!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        WidgetCenter.shared.reloadAllTimelines()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Catch-Up Row

private struct CatchUpRow: View {
    let habit: Habit
    let date: Date

    @State private var isMarked: Bool = false

    var body: some View {
        Button {
            isMarked.toggle()
            habit.toggleCompletion(on: date)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: habit.icon)
                    .font(.title3)
                    .foregroundColor(habit.displayColor)
                    .frame(width: 40, height: 40)
                    .background(
                        habit.displayColor.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                Text(habit.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isMarked ? habit.displayColor : .secondary.opacity(0.3))
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}
