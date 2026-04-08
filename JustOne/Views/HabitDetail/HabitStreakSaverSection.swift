//
//  HabitStreakSaverSection.swift
//  JustOne
//
//  Contribution graph and streak saver controls.
//

import SwiftUI

struct HabitContributionSection: View {
    let habit: Habit
    let habitHistoryWeeksLabel: Int
    var onDayTapped: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.justPrimary)
                Text("Activity")
                    .font(.headline)
                Spacer()
                Text("Last \(habitHistoryWeeksLabel) week\(habitHistoryWeeksLabel == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ContributionGraphView(habit: habit) { date in
                // Only allow streak savers on past, uncompleted days
                let startOfToday = Calendar.current.startOfDay(for: Date())
                if !habit.isCompleted(on: date) && date < startOfToday {
                    onDayTapped(date)
                }
            }
        }
        .padding(20)
        .glassCard()
    }
}

struct HabitStreakSaverControls: View {
    @Environment(PurchaseManager.self) var purchaseManager
    @Binding var showConsumableShop: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bandage.fill")
                    .foregroundColor(.justWarning)
                Text("Streak Savers")
                    .font(.headline)
                Spacer()
                if purchaseManager.hasUnlimitedStreakSavers {
                    HStack(spacing: 4) {
                        Image(systemName: "infinity")
                        Text("Unlimited")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.justSuccess)
                } else {
                    Text("\(purchaseManager.streakSaverTokens) remaining")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.justPrimary)
                }
            }

            Text("Tap a missed day on the graph above to fill it in and protect your streak.")
                .font(.caption)
                .foregroundColor(.secondary)

            if !purchaseManager.hasUnlimitedStreakSavers {
                Button { showConsumableShop = true } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Get More Streak Savers")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(.justPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.justPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(20)
        .glassCard()
    }
}
