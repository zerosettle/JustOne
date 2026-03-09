//
//  HomeDashboardView.swift
//  JustOne
//
//  Main dashboard: dynamic greeting, aggregated heatmap,
//  habit list with mini heatmaps and one-tap logging,
//  and a floating "+" button. Free users see a locked ghost card.
//

import SwiftUI
import SwiftData
import UIKit
import ZeroSettleKit

private struct ClearListRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
    }
}

struct HomeDashboardView: View {
    @Query var habits: [Habit]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) var authVM
    @Environment(ZeroSettleManager.self) var iapManager

    @State private var showAddStandard = false
    @State private var showAddJourney = false
    @State private var showPremiumUpsell = false
    @State private var selectedHeatmapDate: Date?
    @State private var levelUpHabit: Habit?
    @State private var habitToDelete: Habit?
    @State private var navigatingHabit: Habit?
    @State private var touchedHeatmapCell: (week: Int, day: Int)?
    @State private var heatmapDragActive = false  // true once finger moves to a 2nd cell
    @State private var heatmapContainerWidth: CGFloat = 0
    @State private var statsSheetMode: StatsSheetMode?
    @State private var showArchived = false
    @State private var showPreviousDayCatchUp = false
    @Environment(\.scenePhase) private var scenePhase

    private let heatmapCellSpacing: CGFloat = 3

    /// Total columns to display — fills the card width at ~18pt cells, capped at 16.
    private var heatmapWeeks: Int {
        guard heatmapContainerWidth > 0 else { return 4 }
        let gridWidth = heatmapContainerWidth - heatmapDayLabelWidth - heatmapCellSpacing
        let targetCellSize: CGFloat = 18
        let fillWeeks = Int((gridWidth + heatmapCellSpacing) / (targetCellSize + heatmapCellSpacing))
        return max(4, min(fillWeeks, 16))
    }

    /// How many calendar weeks the user's history spans (join week through current week).
    private var heatmapHistoryWeeks: Int {
        let calendar = Calendar.current
        guard let oldest = activeHabits.map(\.createdAt).min(),
              let joinStart = calendar.dateInterval(of: .weekOfYear, for: oldest)?.start,
              let nowStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return max(1, (calendar.dateComponents([.weekOfYear], from: joinStart, to: nowStart).weekOfYear ?? 0) + 1)
    }

    /// Reference date for the heatmap WeekCalendar.
    /// When the user has less history than columns, shifts the reference into the
    /// future so the join week sits at column 0 and empty future weeks fill the right.
    private var heatmapReferenceDate: Date {
        let calendar = Calendar.current
        let history = heatmapHistoryWeeks
        guard history > 0, history < heatmapWeeks else { return Date() }
        // Push reference forward so WeekCalendar's backward count lands on the join week
        return calendar.date(byAdding: .weekOfYear, value: heatmapWeeks - history, to: Date()) ?? Date()
    }

    /// Habits visible on the home screen (active + paused). Excludes archived.
    private var visibleHabits: [Habit] {
        habits.filter { $0.status != .archived }
    }

    /// Only active habits — used for stats, heatmap, and greeting.
    private var activeHabits: [Habit] {
        habits.filter { $0.status == .active }
    }

    /// Archived habits — shown when the archive filter is active.
    private var archivedHabits: [Habit] {
        habits.filter { $0.status == .archived }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.justBackground.ignoresSafeArea()

                List {
                    headerSection
                        .modifier(ClearListRowModifier())

                    heatmapCard
                        .modifier(ClearListRowModifier())
                        // Smoothly animates the List row height when the detail view appears
                        .animation(.bouncy, value: selectedHeatmapDate)

                    habitsListContent
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 100)

                // Floating add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addButton
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .alert(
                "Delete \(habitToDelete?.name ?? "habit")?",
                isPresented: Binding(
                    get: { habitToDelete != nil },
                    set: { if !$0 { habitToDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    habitToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let habit = habitToDelete {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            modelContext.delete(habit)
                        }
                        habitToDelete = nil
                    }
                }
            } message: {
                Text("This will permanently delete this habit and all its history. This cannot be undone.")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if !archivedHabits.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showArchived.toggle()
                                }
                            } label: {
                                Image(systemName: showArchived ? "archivebox.fill" : "archivebox")
                                    .foregroundColor(showArchived ? .justPrimary : .secondary)
                            }
                        }

                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "person.circle")
                                .foregroundColor(.justPrimary)
                        }
                    }
                }
            }
            .onChange(of: archivedHabits.count) { _, newCount in
                if newCount == 0 && showArchived {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showArchived = false
                    }
                }
            }
            .navigationDestination(item: $navigatingHabit) { habit in
                HabitDetailView(habit: habit)
            }
            .sheet(isPresented: $showAddStandard) { AddHabitView() }
            .sheet(isPresented: $showAddJourney) {
                NavigationStack {
                    AddHabitWizardView()
                        .navigationTitle("New Journey")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAddJourney = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showPremiumUpsell) {
                PremiumUpsellView()
            }
            .sheet(item: $statsSheetMode) { mode in
                StatsSheetView(mode: mode, habits: habits)
            }
            .task {
                // Preload checkout webviews for all available products
                if let userId = authVM.appleUserID {
                    for product in ZeroSettle.shared.products {
                        await CheckoutSheet.warmUp(productId: product.id, userId: userId)
                    }
                }
            }
            .sheet(isPresented: $showPreviousDayCatchUp) {
                PreviousDayCatchUpView(habits: activeHabits)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                handleForegroundEntry()
            }
            .sheet(item: $levelUpHabit) { habit in
                LevelUpSheetView(
                    habit: habit,
                    onAccept: {
                        habit.levelUp()
                        levelUpHabit = nil
                    },
                    onDefer: {
                        levelUpHabit = nil
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var firstName: String {
        let full = authVM.currentUser?.displayName ?? "Friend"
        return full.components(separatedBy: " ").first ?? full
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(firstName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(greetingSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !activeHabits.isEmpty {
                progressSummary
                    .padding(.top, 8)
            }
        }
        .padding(.top, 12)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case  5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    // MARK: - Progress Summary

    private var dailyProgress: (completed: Int, total: Int) {
        let total = activeHabits.count
        let completed = activeHabits.filter { $0.isCompleted(on: Date()) }.count
        return (completed, total)
    }

    private var weeklyProgress: (completed: Int, total: Int) {
        let total = activeHabits.reduce(0) { $0 + $1.frequencyPerWeek }
        let completed = activeHabits.reduce(0) { $0 + $1.completionsInWeek() }
        return (min(completed, total), total)
    }

    private var progressSummary: some View {
        let daily = dailyProgress
        let weekly = weeklyProgress
        let dailyPct = daily.total > 0 ? Int(Double(daily.completed) / Double(daily.total) * 100) : 0
        let weeklyPct = weekly.total > 0 ? Int(Double(weekly.completed) / Double(weekly.total) * 100) : 0

        return HStack(spacing: 12) {
            Button { statsSheetMode = .daily } label: {
                progressPill(label: "Today", value: "\(dailyPct)%", detail: "\(daily.completed)/\(daily.total)", filled: dailyPct == 100)
            }
            .buttonStyle(.plain)

            Button { statsSheetMode = .weekly } label: {
                progressPill(label: "This week", value: "\(weeklyPct)%", detail: "\(weekly.completed)/\(weekly.total)", filled: weeklyPct == 100)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func progressPill(label: String, value: String, detail: String, filled: Bool) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundColor(filled ? .white : .primary)
            Text(label)
                .font(.caption)
                .foregroundColor(filled ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .modifier(GlassEffectModifier(
            tint: filled ? Color.justSuccess : nil,
            shape: .capsule
        ))
    }

    private var greetingSubtitle: String {
        guard !activeHabits.isEmpty else { return "Start your first habit today" }
        let remaining = activeHabits.filter { !$0.isCompleted(on: Date()) }.count
        if remaining == 0 {
            return "All done for today"
        } else if remaining == activeHabits.count {
            return "\(remaining) habit\(remaining == 1 ? "" : "s") to go today"
        } else {
            return "\(remaining) more to go today"
        }
    }

    // MARK: - Aggregated Heatmap Card

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.justPrimary)
                Text("Your Progress")
                    .font(.headline)
                Spacer()

                // ZStack ensures smooth morphing/crossfade between states
                ZStack(alignment: .trailing) {
                    if selectedHeatmapDate != nil {
                        Button {
                            withAnimation(.bouncy) {
                                selectedHeatmapDate = Date()
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
                        Text("Last \(min(heatmapHistoryWeeks, heatmapWeeks)) weeks")
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
                aggregatedHeatmap
            }
        }
        .padding(20)
        .glassCard()
    }

    private let heatmapDayLabelWidth: CGFloat = 20

    private func heatmapCellSize(for containerWidth: CGFloat) -> CGFloat {
        let gridWidth = containerWidth - heatmapDayLabelWidth - heatmapCellSpacing
        return max(8, (gridWidth - CGFloat(heatmapWeeks - 1) * heatmapCellSpacing) / CGFloat(heatmapWeeks))
    }

    private var aggregatedHeatmap: some View {
        let wc = WeekCalendar(weeksToShow: heatmapWeeks, referenceDate: heatmapReferenceDate)
        let daySymbols = Calendar.current.shortWeekdaySymbols
        let firstWeekday = Calendar.current.firstWeekday
        let orderedSymbols = (0..<7).map { daySymbols[(firstWeekday - 1 + $0) % 7] }
        let cellSize = heatmapCellSize(for: heatmapContainerWidth)
        let stride = cellSize + heatmapCellSpacing

        return VStack(spacing: 12) {
            // Month labels
            HStack(spacing: 0) {
                Color.clear.frame(width: heatmapDayLabelWidth + heatmapCellSpacing)
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
            HStack(alignment: .top, spacing: heatmapCellSpacing) {
                // Day-of-week labels
                VStack(spacing: heatmapCellSpacing) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(orderedSymbols[i].prefix(1).uppercased())
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .frame(width: heatmapDayLabelWidth, height: cellSize)
                    }
                }

                // Week columns
                HStack(spacing: heatmapCellSpacing) {
                    ForEach(0..<heatmapWeeks, id: \.self) { weekIndex in
                        VStack(spacing: heatmapCellSpacing) {
                            ForEach(0..<7, id: \.self) { dayOfWeek in
                                let date = wc.date(week: weekIndex, day: dayOfWeek)
                                let today = Calendar.current.startOfDay(for: Date())
                                let isFuture = date > today
                                let intensity = isFuture ? -1.0 : heatmapIntensity(on: date)
                                let isSelected = selectedHeatmapDate.map {
                                    Calendar.current.isDate($0, inSameDayAs: date)
                                } ?? false
                                let touchGlow = heatmapTouchGlow(week: weekIndex, day: dayOfWeek)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(heatmapCellColor(intensity: intensity))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.justPrimary.opacity(touchGlow * 0.6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.justPrimary, lineWidth: isSelected ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        guard !isFuture else { return }
                                        withAnimation(.bouncy) {
                                            if isSelected {
                                                selectedHeatmapDate = nil
                                            } else {
                                                selectedHeatmapDate = date
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
                            if week >= 0, week < heatmapWeeks, day >= 0, day < 7 {
                                let isNewCell = touchedHeatmapCell?.week != week || touchedHeatmapCell?.day != day
                                if isNewCell && touchedHeatmapCell != nil && !heatmapDragActive {
                                    heatmapDragActive = true
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedHeatmapDate = nil
                                    }
                                }
                                touchedHeatmapCell = (week: week, day: day)
                                if isNewCell && heatmapDragActive {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } else if touchedHeatmapCell != nil {
                                touchedHeatmapCell = nil
                                heatmapDragActive = false
                            }
                        }
                        .onEnded { _ in
                            if heatmapDragActive, let touched = touchedHeatmapCell {
                                let date = wc.date(week: touched.week, day: touched.day)
                                let today = Calendar.current.startOfDay(for: Date())
                                if date <= today {
                                    withAnimation(.bouncy) {
                                        selectedHeatmapDate = date
                                    }
                                }
                            }
                            touchedHeatmapCell = nil
                            heatmapDragActive = false
                        }
                )
            }

            if let selected = selectedHeatmapDate {
                heatmapDayDetail(for: selected)
                    // Pure opacity fade works perfectly with the VStack's .animation(.bouncy)
                    // to naturally expand the space downward like an accordion.
                    .transition(.opacity)
            }
        }
        .clipped()
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { heatmapContainerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in heatmapContainerWidth = w }
            }
        )
    }

    /// Returns 0.0–1.0 glow intensity based on proximity to the touched cell.
    private func heatmapTouchGlow(week: Int, day: Int) -> Double {
        guard heatmapDragActive, let touched = touchedHeatmapCell else { return 0 }
        let dx = Double(week - touched.week)
        let dy = Double(day - touched.day)
        let distance = sqrt(dx * dx + dy * dy)
        if distance < 0.1 { return 1.0 }
        let glow = max(0, 1.0 - distance / 2.5)
        return glow * glow // quadratic falloff for a tighter halo
    }

    private func heatmapDayDetail(for date: Date) -> some View {
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

    private func heatmapCellColor(intensity: Double) -> Color {
        if intensity < 0 { return Color.secondary.opacity(0.06) }
        if intensity == 0 { return Color.justPrimary.opacity(0.08) }
        return Color.justPrimary.opacity(0.15 + intensity * 0.85)
    }

    // MARK: - Habits Section (List rows)

    /// The habits to display based on the current filter.
    private var displayedHabits: [Habit] {
        showArchived ? archivedHabits : visibleHabits
    }

    @ViewBuilder
    private var habitsListContent: some View {
        // Section header
        HStack {
            Text(showArchived ? "Archived Habits" : "Your Habits")
                .font(.headline)
            Spacer()
            if !showArchived && iapManager.isPremium {
                Text("Pro")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.justPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.justPrimary.opacity(0.12), in: Capsule())
            }
        }
        .modifier(ClearListRowModifier())

        if displayedHabits.isEmpty {
            if showArchived {
                archivedEmptyState
                    .modifier(ClearListRowModifier())
            } else {
                emptyState
                    .modifier(ClearListRowModifier())
            }
        } else {
            ForEach(displayedHabits) { habit in
                Button {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigatingHabit = habit
                    }
                } label: {
                    HabitRowView(
                        habit: habit,
                        onToggleToday: {
                            guard habit.status == .active else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                habit.toggleCompletionAndReloadWidget(on: Date())
                            }
                            UIImpactFeedbackGenerator(style: habit.isCompleted(on: Date()) ? .medium : .light).impactOccurred()
                            if habit.isCompleted(on: Date()) && habit.qualifiesForLevelUp() {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    levelUpHabit = habit
                                }
                            }
                        },
                        onAffirmToday: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if habit.isAffirmed(on: Date()) {
                                    habit.undoAffirmAndReloadWidget(on: Date())
                                } else {
                                    habit.affirmDayAndReloadWidget(on: Date())
                                }
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        },
                        onSlipToday: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if !habit.isCompleted(on: Date()) {
                                    // Currently slipped — undo
                                    habit.undoSlipAndReloadWidget(on: Date())
                                } else {
                                    habit.logSlipAndReloadWidget(on: Date())
                                }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    )
                }
                .buttonStyle(LiquidPressStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        habitToDelete = habit
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)

                    if showArchived {
                        Button {
                            habit.status = .active
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    } else {
                        Button {
                            habit.status = .archived
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if !showArchived {
                        if habit.status == .paused {
                            Button {
                                habit.status = .active
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .tint(.green)
                        } else {
                            Button {
                                habit.status = .paused
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                            .tint(.yellow)
                        }
                    }
                }
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20))
                .contextMenu {
                    if showArchived {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                habit.status = .active
                            }
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                    } else {
                        if habit.status == .paused {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    habit.status = .active
                                }
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                        } else {
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    habit.status = .paused
                                }
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                habit.status = .archived
                            }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }

                    Button(role: .destructive) {
                        habitToDelete = habit
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
            }

            if !showArchived && !iapManager.isPremium {
                lockedHabitCard
                    .modifier(ClearListRowModifier())
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 48))
                .foregroundColor(.justPrimary.opacity(0.5))

            Text("Start your journey")
                .font(.headline)

            Text("Tap + to create your first habit")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    private var archivedEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No archived habits")
                .font(.headline)

            Text("Habits you archive will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    // MARK: - Locked Habit Card (Free Users)

    private var lockedHabitCard: some View {
        Button { showPremiumUpsell = true } label: {
            HStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundColor(.secondary.opacity(0.4))
                    .frame(width: 48, height: 48)
                    .background(
                        Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Track another habit")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Multiple streaks are part of JustOne Pro")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                }

                Spacer()

                Text("Pro")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.justPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.justPrimary.opacity(0.12), in: Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .padding(16)
            .glassCard()
            .opacity(0.7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Floating Add Button

    private var addButton: some View {
        Menu {
            Button {
                handleAddTapped(journey: false)
            } label: {
                Label("Standard Habit", systemImage: "checkmark.circle")
            }

            Button {
                handleAddTapped(journey: true)
            } label: {
                Label("Progressive Journey", systemImage: "chart.line.uptrend.xyaxis")
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .modifier(GlassEffectModifier(tint: Color.justPrimary.opacity(0.8), shape: .circle))
        }
    }

    // MARK: - Foreground Lifecycle

    private func handleForegroundEntry() {
        // Schedule or cancel end-of-day reminder
        if NotificationManager.isReminderEnabled {
            let incompleteCount = activeHabits.filter { !$0.isCompleted(on: Date()) }.count
            let time = NotificationManager.reminderTimeComponents
            Task {
                await NotificationManager.shared.scheduleEndOfDayReminder(
                    incompleteCount: incompleteCount,
                    at: time
                )
            }
        }

        // Check for previous-day catch-up (Pro only)
        let today = Habit.dateKey(for: Date())
        let lastOpened = UserDefaults.standard.string(forKey: "lastOpenedDate")
        UserDefaults.standard.set(today, forKey: "lastOpenedDate")

        if lastOpened != nil && lastOpened != today && iapManager.isPremium {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let hadIncomplete = activeHabits.contains { !$0.isCompleted(on: yesterday) }
            if hadIncomplete {
                showPreviousDayCatchUp = true
            }
        }
    }

    private func handleAddTapped(journey: Bool) {
        guard iapManager.canCreateHabit(currentHabitCount: habits.count) else {
            showPremiumUpsell = true
            return
        }
        if journey {
            showAddJourney = true
        } else {
            showAddStandard = true
        }
    }
}

// MARK: - Glass Effect Compatibility

/// Applies `.glassEffect` on iOS 26+, falls back to a tinted background on older versions.
private struct GlassEffectModifier: ViewModifier {
    var tint: Color?
    var shape: GlassShape = .capsule

    enum GlassShape {
        case capsule, circle
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule:
                if let tint {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
                } else {
                    content.glassEffect(.regular.interactive(), in: .capsule)
                }
            case .circle:
                if let tint {
                    content.glassEffect(.regular.tint(tint).interactive(), in: .circle)
                } else {
                    content.glassEffect(.regular.interactive(), in: .circle)
                }
            }
        } else {
            switch shape {
            case .capsule:
                content.background(tint?.opacity(0.15) ?? Color(.secondarySystemBackground), in: Capsule())
            case .circle:
                content.background(tint ?? Color(.secondarySystemBackground), in: Circle())
            }
        }
    }
}
