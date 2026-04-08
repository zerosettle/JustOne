//
//  HabitHeroCardView.swift
//  JustOne
//
//  Hero card showing habit icon, name, goal, and weekly progress bar.
//

import SwiftUI

struct HabitHeroCardView: View {
    let habit: Habit

    var body: some View {
        VStack(spacing: 12) {
            if habit.status == .paused {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle.fill")
                    Text("Paused")
                        .fontWeight(.medium)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            Image(systemName: habit.icon)
                .font(.system(size: 44))
                .foregroundColor(habit.displayColor)
                .frame(width: 80, height: 80)
                .background(
                    habit.displayColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 24)
                )

            Text(habit.name)
                .font(.title2.weight(.bold))

            if let config = habit.journeyConfig {
                Text("Journey: \(config.formattedValue(config.startValue)) \u{2192} \(config.formattedValue(config.goalValue))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Goal: \(habit.frequencyPerWeek)\u{00D7} per week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Weekly progress bar
            let progress = habit.weeklyProgress()
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(habit.displayColor.opacity(0.15))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(habit.displayColor)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(habit.completionsInWeek())/\(habit.frequencyPerWeek) this week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if progress >= 1.0 {
                        Label("Consistent", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.justSuccess)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
