//
//  AggregatedHeatmapView.swift
//  JustOne
//
//  Aggregated heatmap card showing habit completion across
//  all active habits. Supports tap-to-select and drag-to-explore.
//

import SwiftUI
import UIKit

struct AggregatedHeatmapView: View {
    let activeHabits: [Habit]
    @Binding var selectedDate: Date?

    @State private var touchedCell: (week: Int, day: Int)?
    @State private var dragActive = false
    @State private var containerWidth: CGFloat = 0

    private let cellSpacing: CGFloat = 3
    private let dayLabelWidth: CGFloat = 20

    // MARK: - Computed Layout

    /// Total columns to display — fills the card width at ~18pt cells, capped at 16.
    private var weeks: Int {
        guard containerWidth > 0 else { return 4 }
        let gridWidth = containerWidth - dayLabelWidth - cellSpacing
        let targetCellSize: CGFloat = 18
        let fillWeeks = Int((gridWidth + cellSpacing) / (targetCellSize + cellSpacing))
        return max(4, min(fillWeeks, 16))
    }

    /// How many calendar weeks the user's history spans (join week through current week).
    private var historyWeeks: Int {
        let calendar = Calendar.current
        guard let oldest = activeHabits.map(\.createdAt).min(),
              let joinStart = calendar.dateInterval(of: .weekOfYear, for: oldest)?.start,
              let nowStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return max(1, (calendar.dateComponents([.weekOfYear], from: joinStart, to: nowStart).weekOfYear ?? 0) + 1)
    }

    /// Reference date for the heatmap WeekCalendar.
    private var referenceDate: Date {
        let calendar = Calendar.current
        let history = historyWeeks
        guard history > 0, history < weeks else { return Date() }
        return calendar.date(byAdding: .weekOfYear, value: weeks - history, to: Date()) ?? Date()
    }

    private func cellSize(for width: CGFloat) -> CGFloat {
        let gridWidth = width - dayLabelWidth - cellSpacing
        return max(8, (gridWidth - CGFloat(weeks - 1) * cellSpacing) / CGFloat(weeks))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.justPrimary)
                Text("Your Progress")
                    .font(.headline)
                Spacer()

                ZStack(alignment: .trailing) {
                    if selectedDate != nil {
                        Button {
                            withAnimation(.bouncy) {
                                selectedDate = Date()
                            }
                        } label: {
                            Text("Today")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.justPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderless)
                        .modifier(GlassEffectModifier(shape: .capsule))
                        .transition(.opacity)
                    } else {
                        Text("Last \(min(historyWeeks, weeks)) weeks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }
                }
            }

            if activeHabits.isEmpty {
                Text("Start a habit to see your progress here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                heatmapGrid
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Grid

    private var heatmapGrid: some View {
        let wc = WeekCalendar(weeksToShow: weeks, referenceDate: referenceDate)
        let daySymbols = Calendar.current.shortWeekdaySymbols
        let firstWeekday = Calendar.current.firstWeekday
        let orderedSymbols = (0..<7).map { daySymbols[(firstWeekday - 1 + $0) % 7] }
        let size = cellSize(for: containerWidth)
        let stride = size + cellSpacing

        return VStack(spacing: 12) {
            // Month labels
            HStack(spacing: 0) {
                Color.clear.frame(width: dayLabelWidth + cellSpacing)
                ZStack(alignment: .leading) {
                    ForEach(wc.monthLabels, id: \.index) { entry in
                        Text(entry.name)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .offset(x: CGFloat(entry.index) * stride)
                    }
                }
                Spacer()
            }
            .frame(height: 14)

            // Grid
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day-of-week labels
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(orderedSymbols[i].prefix(1).uppercased())
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: dayLabelWidth, height: size)
                    }
                }

                // Week columns
                HStack(spacing: cellSpacing) {
                    ForEach(0..<weeks, id: \.self) { weekIndex in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { dayOfWeek in
                                let date = wc.date(week: weekIndex, day: dayOfWeek)
                                let today = Calendar.current.startOfDay(for: Date())
                                let isFuture = date > today
                                let intensity = isFuture ? -1.0 : heatmapIntensity(on: date)
                                let isSelected = selectedDate.map {
                                    Calendar.current.isDate($0, inSameDayAs: date)
                                } ?? false
                                let touchGlow = touchGlowIntensity(week: weekIndex, day: dayOfWeek)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cellColor(intensity: intensity))
                                    .frame(width: size, height: size)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.justPrimary.opacity(touchGlow * 0.6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.justPrimary, lineWidth: isSelected ? 2 : 0)
                                    )
                                    .accessibilityLabel(isFuture ? "Future date" : cellAccessibilityLabel(for: date))
                                    .onTapGesture {
                                        guard !isFuture else { return }
                                        withAnimation(.bouncy) {
                                            if isSelected {
                                                selectedDate = nil
                                            } else {
                                                selectedDate = date
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .coordinateSpace(name: "heatmapGrid")
                .simultaneousGesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .named("heatmapGrid"))
                        .onChanged { value in
                            let week = Int(value.location.x / stride)
                            let day = Int(value.location.y / stride)
                            if week >= 0, week < weeks, day >= 0, day < 7 {
                                let isNewCell = touchedCell?.week != week || touchedCell?.day != day
                                if isNewCell && touchedCell != nil && !dragActive {
                                    dragActive = true
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedDate = nil
                                    }
                                }
                                touchedCell = (week: week, day: day)
                                if isNewCell && dragActive {
                                    HapticFeedback.impact(.light)
                                }
                            } else if touchedCell != nil {
                                touchedCell = nil
                                dragActive = false
                            }
                        }
                        .onEnded { _ in
                            if dragActive, let touched = touchedCell {
                                let date = wc.date(week: touched.week, day: touched.day)
                                let today = Calendar.current.startOfDay(for: Date())
                                if date <= today {
                                    withAnimation(.bouncy) {
                                        selectedDate = date
                                    }
                                }
                            }
                            touchedCell = nil
                            dragActive = false
                        }
                )
            }

            if let selected = selectedDate {
                dayDetail(for: selected)
                    .transition(.opacity)
            }
        }
        .clipped()
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in containerWidth = w }
            }
        )
    }

    // MARK: - Day Detail

    private func dayDetail(for date: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let existing = habitsExisting(on: date)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatter.string(from: date))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                let completed = existing.filter { $0.isCompleted(on: date) }.count
                Text("\(completed)/\(existing.count)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }

            ForEach(existing) { habit in
                HStack(spacing: 10) {
                    Image(systemName: habit.isCompleted(on: date) ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline)
                        .foregroundColor(
                            habit.isCompleted(on: date)
                                ? habit.displayColor
                                : .secondary.opacity(0.3)
                        )

                    Text(habit.name)
                        .font(.subheadline)
                        .foregroundColor(habit.isCompleted(on: date) ? .primary : .secondary)
                }
            }
        }
        .padding(12)
        .background(Color.justSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    /// Returns 0.0–1.0 glow intensity based on proximity to the touched cell.
    private func touchGlowIntensity(week: Int, day: Int) -> Double {
        guard dragActive, let touched = touchedCell else { return 0 }
        let dx = Double(week - touched.week)
        let dy = Double(day - touched.day)
        let distance = sqrt(dx * dx + dy * dy)
        if distance < 0.1 { return 1.0 }
        let glow = max(0, 1.0 - distance / 2.5)
        return glow * glow // quadratic falloff for a tighter halo
    }

    /// Habits that existed on a given date (created on or before that date).
    private func habitsExisting(on date: Date) -> [Habit] {
        let dayStart = Calendar.current.startOfDay(for: date)
        return activeHabits.filter { Calendar.current.startOfDay(for: $0.createdAt) <= dayStart }
    }

    private func heatmapIntensity(on date: Date) -> Double {
        let existing = habitsExisting(on: date)
        guard !existing.isEmpty else { return 0 }
        let completed = existing.filter { $0.isCompleted(on: date) }.count
        return Double(completed) / Double(existing.count)
    }

    private func cellAccessibilityLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let existing = habitsExisting(on: date)
        let completed = existing.filter { $0.isCompleted(on: date) }.count
        return "\(formatter.string(from: date)): \(completed) of \(existing.count) habits completed"
    }

    private func cellColor(intensity: Double) -> Color {
        if intensity < 0 { return Color.secondary.opacity(0.06) }
        if intensity == 0 { return Color.justPrimary.opacity(0.08) }
        return Color.justPrimary.opacity(0.15 + intensity * 0.85)
    }
}
