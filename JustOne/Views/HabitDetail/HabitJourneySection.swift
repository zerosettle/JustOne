//
//  HabitJourneySection.swift
//  JustOne
//
//  Journey progress timeline with level-up and step-back controls.
//

import SwiftUI

struct HabitJourneySection: View {
    let habit: Habit
    @Binding var showLevelUp: Bool

    var body: some View {
        if let config = habit.journeyConfig {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(.justPrimary)
                    Text("Journey Progress")
                        .font(.headline)
                    Spacer()
                    Text("Level \(config.currentLevel + 1) of \(config.totalLevels)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                JourneyTimelineView(
                    journeyConfig: config,
                    accentColor: habit.displayColor
                )

                if config.isAtFinalLevel {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.justWarning)
                        Text("Journey Complete!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.justWarning)
                        Spacer()
                        Button {
                            withAnimation { habit.levelDown() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                Text("Step Back")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        if config.currentLevel > 0 {
                            Button {
                                withAnimation { habit.levelDown() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Step Back")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            showLevelUp = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle")
                                Text("Advance")
                            }
                            .font(.subheadline)
                            .foregroundColor(.justPrimary)
                        }
                    }
                }
            }
            .padding(20)
            .glassCard()
        }
    }
}
