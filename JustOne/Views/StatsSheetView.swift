//
//  StatsSheetView.swift
//  JustOne
//
//  Bottom sheet showing daily or weekly habit stats,
//  presented when the user taps a progress pill on the dashboard.
//

import SwiftUI

// MARK: - Mode

enum StatsSheetMode: Identifiable {
    case daily, weekly

    var id: Int {
        switch self {
        case .daily: return 0
        case .weekly: return 1
        }
    }
}

// MARK: - View

struct StatsSheetView: View {
    let mode: StatsSheetMode
    let habits: [Habit]

    @State private var contentHeight: CGFloat = 300

    private var activeHabits: [Habit] {
        habits.filter { $0.status == .active }
    }

    var body: some View {
        VStack(spacing: 20) {
            switch mode {
            case .daily:  dailyContent
            case .weekly: weeklyContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.height) {
                        contentHeight = proxy.size.height
                    }
            }
        )
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Daily

    private var dailyProgress: (completed: Int, total: Int) {
        let total = activeHabits.count
        let completed = activeHabits.filter { $0.isCompleted(on: Date()) }.count
        return (completed, total)
    }

    private var dailyContent: some View {
        let progress = dailyProgress
        let fraction = progress.total > 0
            ? Double(progress.completed) / Double(progress.total)
            : 0

        return VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Today's Progress")
                    .font(.title3.weight(.bold))
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Completion ring
            ZStack {
                Circle()
                    .stroke(Color.justPrimary.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        Color.justPrimary,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: fraction)

                VStack(spacing: 2) {
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text("done")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // Habit checklist
            if !activeHabits.isEmpty {
                VStack(spacing: 8) {
                    ForEach(activeHabits) { habit in
                        HStack(spacing: 10) {
                            Image(systemName: habit.isCompleted(on: Date())
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.subheadline)
                                .foregroundColor(
                                    habit.isCompleted(on: Date())
                                        ? habit.accentColor.color
                                        : .secondary.opacity(0.3)
                                )
                            Text(habit.name)
                                .font(.subheadline)
                                .foregroundColor(
                                    habit.isCompleted(on: Date()) ? .primary : .secondary
                                )
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(Color.justSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }

            // Motivational line
            Text(dailyMotivation(completed: progress.completed, total: progress.total))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func dailyMotivation(completed: Int, total: Int) -> String {
        if total == 0 {
            return "Start your first habit today"
        } else if completed == total {
            return "All done! Great job today."
        } else if completed == 0 {
            return "Start your first one — you've got this"
        } else {
            return "\(total - completed) more to go — keep it up!"
        }
    }

    // MARK: - Weekly

    private var weeklyProgress: (completed: Int, total: Int) {
        let total = activeHabits.reduce(0) { $0 + $1.frequencyPerWeek }
        let completed = activeHabits.reduce(0) { $0 + $1.completionsInWeek() }
        return (min(completed, total), total)
    }

    private var weeklyContent: some View {
        let progress = weeklyProgress
        let fraction = progress.total > 0
            ? Double(progress.completed) / Double(progress.total)
            : 0

        return VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("This Week")
                    .font(.title3.weight(.bold))
                Text(weekDateRange)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            VStack(spacing: 6) {
                HStack {
                    Text("\(progress.completed)/\(progress.total) completions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(fraction * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundColor(.justPrimary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.justPrimary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.justPrimary)
                            .frame(width: geo.size.width * fraction)
                            .animation(.easeInOut(duration: 0.5), value: fraction)
                    }
                }
                .frame(height: 10)
            }

            // Per-habit breakdown
            if !activeHabits.isEmpty {
                VStack(spacing: 10) {
                    ForEach(activeHabits) { habit in
                        habitWeeklyRow(habit)
                    }
                }
                .padding(16)
                .background(Color.justSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            }

            // Streak callout (best streak across habits, shown only if ≥ 1)
            if let maxStreak = activeHabits.map(\.currentStreak).max(), maxStreak >= 1 {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.justWarning)
                    Text("\(maxStreak) week streak")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(12)
                .background(Color.justWarning.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            // Monthly consistency
            HStack {
                Text("This month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(consistencyThisMonth)%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundColor(.justPrimary)
            }
            .padding(12)
            .background(Color.justSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func habitWeeklyRow(_ habit: Habit) -> some View {
        let completed = habit.completionsInWeek()
        let total = habit.frequencyPerWeek
        let fraction = total > 0 ? min(Double(completed) / Double(total), 1.0) : 0

        return HStack(spacing: 12) {
            Image(systemName: habit.icon)
                .font(.caption)
                .foregroundColor(habit.accentColor.color)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(habit.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(completed)/\(total)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundColor(fraction >= 1.0 ? .justSuccess : .secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(habit.accentColor.color.opacity(0.15))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(habit.accentColor.color)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: - Helpers

    private var weekDateRange: String {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return "" }
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: end))"
    }

    /// Duplicated from SettingsView — operates on the passed-in habits array
    /// rather than @Query so it works in a sheet context.
    private var consistencyThisMonth: Int {
        let calendar = Calendar.current
        let today = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: today) else { return 0 }

        let daysElapsed = max(
            calendar.dateComponents([.day], from: monthInterval.start, to: today).day ?? 0, 1
        )

        var totalExpected = 0
        var totalCompleted = 0

        for habit in activeHabits {
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
}
