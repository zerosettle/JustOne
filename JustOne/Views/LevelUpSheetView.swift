//
//  LevelUpSheetView.swift
//  JustOne
//
//  Celebration bottom sheet shown when a user qualifies for a journey level-up.
//  Offers "Yes, level up" or "Not yet, keep me here" choices.
//

import SwiftUI

struct LevelUpSheetView: View {
    let habit: Habit
    var onAccept: () -> Void
    var onDefer: () -> Void

    private var config: JourneyConfig? { habit.journeyConfig }

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            // Celebration badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                habit.accentColor.color,
                                habit.accentColor.color.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            Text("Level Up!")
                .font(.title.weight(.bold))
                .foregroundColor(.primary)

            if let config = config {
                Text("You've crushed \(config.formattedValue(config.currentTarget)) for \(config.pacingDays) days straight.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let next = config.nextTarget {
                    Text("Ready for \(config.formattedValue(next))?")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }

            Spacer().frame(height: 8)

            // Accept button
            Button {
                onAccept()
            } label: {
                Text("Yes, level up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(habit.accentColor.color, in: RoundedRectangle(cornerRadius: 14))
            }

            // Defer button
            Button {
                onDefer()
            } label: {
                Text("Not yet, keep me here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer().frame(height: 4)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}
