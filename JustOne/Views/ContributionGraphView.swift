//
//  ContributionGraphView.swift
//  JustOne
//
//  A GitHub-style contribution / heat-map grid.
//  Rows = days of the week (Mon -> Sun), columns = weeks.
//  Cell brightness scales with weekly completion progress.
//

import SwiftUI
import UIKit

struct ContributionGraphView: View {
    let habit: Habit
    var weeksToShow: Int = 16
    var onDayTapped: ((Date) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Touch Tracking

    @State private var touchedCell: (col: Int, row: Int)?
    @State private var dragActive = false
    @State private var gridSize: CGSize = .zero

    // MARK: - Layout Constants

    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    /// How many calendar weeks the habit's history spans (creation week through current week).
    private var historyWeeks: Int {
        let calendar = Calendar.current
        guard let joinStart = calendar.dateInterval(of: .weekOfYear, for: habit.createdAt)?.start,
              let nowStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return max(1, (calendar.dateComponents([.weekOfYear], from: joinStart, to: nowStart).weekOfYear ?? 0) + 1)
    }

    /// Caps columns to actual history so the grid doesn't render empty future weeks.
    private var effectiveWeeks: Int {
        min(weeksToShow, historyWeeks)
    }

    private var weekCalendar: WeekCalendar {
        WeekCalendar(weeksToShow: effectiveWeeks)
    }

    // MARK: - Body

    var body: some View {
        let wc = weekCalendar
        let weeks = wc.weekStarts

        VStack(alignment: .leading, spacing: 4) {
            monthLabelsRow(wc: wc)

            HStack(alignment: .top, spacing: cellSpacing) {
                // Day-of-week legend
                VStack(spacing: cellSpacing) {
                    ForEach(Array(wc.dayLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: 14, height: cellSize)
                    }
                }

                // Week columns with drag gesture
                HStack(spacing: cellSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.element) { colIndex, weekStart in
                        VStack(spacing: cellSpacing) {
                            ForEach(Array(wc.daysInWeek(weekStart).enumerated()), id: \.element) { rowIndex, date in
                                let glow = touchGlow(col: colIndex, row: rowIndex)

                                dayCellView(for: date)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(habit.accentColor.color.opacity(glow * 0.6))
                                    )
                                    .onTapGesture { onDayTapped?(date) }
                            }
                        }
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { gridSize = geo.size }
                            .onChange(of: geo.size) { _, newSize in gridSize = newSize }
                    }
                )
                .coordinateSpace(name: "contributionGrid")
                .simultaneousGesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .named("contributionGrid"))
                        .onChanged { value in
                            guard gridSize.width > 0 else { return }
                            let col = Int(value.location.x / (cellSize + cellSpacing))
                            let row = Int(value.location.y / (cellSize + cellSpacing))
                            if col >= 0, col < weeks.count, row >= 0, row < 7 {
                                let isNewCell = touchedCell?.col != col || touchedCell?.row != row
                                if isNewCell && touchedCell != nil {
                                    dragActive = true
                                }
                                touchedCell = (col: col, row: row)
                                if isNewCell && dragActive {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } else if touchedCell != nil {
                                touchedCell = nil
                                dragActive = false
                            }
                        }
                        .onEnded { _ in
                            touchedCell = nil
                            dragActive = false
                        }
                )
            }

            legendRow
        }
    }

    // MARK: - Touch Glow

    private func touchGlow(col: Int, row: Int) -> Double {
        guard dragActive, let touched = touchedCell else { return 0 }
        let dx = Double(col - touched.col)
        let dy = Double(row - touched.row)
        let distance = sqrt(dx * dx + dy * dy)
        if distance < 0.1 { return 1.0 }
        let glow = max(0, 1.0 - distance / 2.5)
        return glow * glow
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCellView(for date: Date) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        let isFuture = date > today
        let isCompleted = habit.isCompleted(on: date)
        let weekProgress = habit.weeklyProgress(referenceDate: date)

        RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(isCompleted: isCompleted, isFuture: isFuture, weekProgress: weekProgress, date: date))
            .frame(width: cellSize, height: cellSize)
    }

    private func cellColor(isCompleted: Bool, isFuture: Bool, weekProgress: Double, date: Date) -> Color {
        if isFuture { return Color.gray.opacity(colorScheme == .dark ? 0.12 : 0.06) }
        if isCompleted {
            if let config = habit.journeyConfig {
                let levelIntensity = config.levelIntensity(on: Habit.dateKey(for: date))
                return habit.accentColor.color.opacity(0.4 + levelIntensity * 0.6)
            }
            let intensity = 0.35 + (weekProgress * 0.65)
            return habit.accentColor.color.opacity(intensity)
        }
        return Color.gray.opacity(colorScheme == .dark ? 0.20 : 0.10)
    }

    // MARK: - Month Labels

    private func monthLabelsRow(wc: WeekCalendar) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 14 + cellSpacing)

            ZStack(alignment: .leading) {
                ForEach(wc.monthLabels, id: \.index) { entry in
                    Text(entry.name)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .offset(x: CGFloat(entry.index) * (cellSize + cellSpacing))
                }
            }

            Spacer()
        }
        .frame(height: 14)
    }

    // MARK: - Legend

    private var legendRow: some View {
        let isJourney = habit.journeyConfig != nil

        return HStack(spacing: 4) {
            Spacer()

            Text(isJourney ? "Start" : "Less")
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(legendCellColor(level: level))
                    .frame(width: 10, height: 10)
            }

            Text(isJourney ? "Goal" : "More")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    private func legendCellColor(level: Double) -> Color {
        if level == 0 {
            return Color.gray.opacity(colorScheme == .dark ? 0.20 : 0.10)
        }
        return habit.accentColor.color.opacity(0.35 + level * 0.65)
    }
}
