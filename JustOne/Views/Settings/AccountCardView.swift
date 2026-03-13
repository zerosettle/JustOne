//
//  AccountCardView.swift
//  JustOne
//
//  Account avatar, display name, and aggregate stats
//  (longest streak, monthly consistency).
//

import SwiftUI

struct AccountCardView: View {
    let user: User?
    let habits: [Habit]

    private var longestStreak: Int {
        habits.map(\.currentStreak).max() ?? 0
    }

    private var consistencyThisMonth: Int {
        let calendar = Calendar.current
        let today = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: today) else { return 0 }

        let daysElapsed = max(calendar.dateComponents([.day], from: monthInterval.start, to: today).day ?? 0, 1)

        var totalExpected = 0
        var totalCompleted = 0

        for habit in habits {
            let dailyRate = Double(habit.frequencyPerWeek) / 7.0
            totalExpected += Int(ceil(dailyRate * Double(daysElapsed)))

            var day = monthInterval.start
            while day <= today {
                if habit.isCompleted(on: day) { totalCompleted += 1 }
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
        }

        guard totalExpected > 0 else { return 0 }
        return min(Int(Double(totalCompleted) / Double(totalExpected) * 100), 100)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: user?.avatarSystemName ?? "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient.premiumGradient)

            VStack(spacing: 4) {
                Text(user?.displayName ?? "User")
                    .font(.title3.weight(.semibold))

                if let email = user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if !habits.isEmpty {
                Divider()

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.justWarning)
                            Text("\(longestStreak)")
                                .font(.title3.weight(.bold))
                        }
                        Text(longestStreak == 1 ? "week streak" : "week streak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 36)

                    VStack(spacing: 2) {
                        Text("\(consistencyThisMonth)%")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.justPrimary)
                        Text("this month")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
