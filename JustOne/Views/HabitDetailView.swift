//
//  HabitDetailView.swift
//  JustOne
//
//  Full detail view for a single habit.
//  Shows a hero card, stats, the GitHub-style contribution graph,
//  a "log today" toggle, and streak-saver controls.
//

import SwiftUI
import SwiftData
import UIKit

struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @Environment(ZeroSettleManager.self) var iapManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedDate: Date? = nil
    @State private var showStreakSaverConfirm = false
    @State private var showConsumableShop = false
    @State private var showLevelUp = false
    @State private var showEditJourney = false
    @State private var showConvertToJourney = false
    @State private var showDeleteConfirm = false

    private var habitHistoryWeeksLabel: Int {
        let calendar = Calendar.current
        guard let joinStart = calendar.dateInterval(of: .weekOfYear, for: habit.createdAt)?.start,
              let nowStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 16 }
        let history = max(1, (calendar.dateComponents([.weekOfYear], from: joinStart, to: nowStart).weekOfYear ?? 0) + 1)
        return min(history, 16)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient.justBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    heroCard
                    if habit.isJourney {
                        journeySection
                    }
                    statsRow
                    if habit.status == .active {
                        logTodayButton
                    }
                    contributionSection
                    streakSaverSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if habit.isJourney {
                        Button {
                            showEditJourney = true
                        } label: {
                            Label("Edit Journey", systemImage: "pencil")
                        }

                        Button {
                            withAnimation { habit.convertToStandard() }
                        } label: {
                            Label("Convert to Standard", systemImage: "arrow.uturn.backward")
                        }
                    } else {
                        if habit.pausedJourneyConfig != nil {
                            Button {
                                withAnimation { habit.convertToJourney() }
                            } label: {
                                Label("Restore Journey", systemImage: "arrow.uturn.forward")
                            }
                        }

                        Button {
                            showConvertToJourney = true
                        } label: {
                            Label("Convert to Journey", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }

                    Divider()

                    if habit.status == .paused {
                        Button {
                            withAnimation { habit.status = .active }
                        } label: {
                            Label("Resume Habit", systemImage: "play.fill")
                        }
                    } else {
                        Button {
                            withAnimation { habit.status = .paused }
                        } label: {
                            Label("Pause Habit", systemImage: "pause.fill")
                        }
                    }

                    Button {
                        withAnimation { habit.status = .archived }
                        dismiss()
                    } label: {
                        Label("Archive Habit", systemImage: "archivebox")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Habit", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.justPrimary)
                }
            }
        }
        .fullScreenCover(isPresented: $showConsumableShop) {
            ConsumableShopView()
        }
        .sheet(isPresented: $showLevelUp) {
            LevelUpSheetView(
                habit: habit,
                onAccept: {
                    habit.levelUp()
                    showLevelUp = false
                },
                onDefer: {
                    showLevelUp = false
                }
            )
        }
        .sheet(isPresented: $showEditJourney) {
            NavigationStack {
                AddHabitWizardView(
                    editingHabit: habit,
                    onSave: { newConfig in
                        habit.updateJourneyConfig(newConfig)
                    }
                )
                .navigationTitle("Edit Journey")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEditJourney = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showConvertToJourney) {
            NavigationStack {
                AddHabitWizardView(
                    editingHabit: habit,
                    onSave: { newConfig in
                        habit.convertToJourney(with: newConfig)
                    }
                )
                .navigationTitle("Add Journey")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showConvertToJourney = false }
                    }
                }
            }
        }
        .alert("Use Streak Saver?", isPresented: $showStreakSaverConfirm) {
            Button("Use Token", role: .destructive) {
                if let date = selectedDate {
                    _ = habit.fillMissedDay(on: date, using: iapManager)
                }
                selectedDate = nil
            }
            Button("Cancel", role: .cancel) { selectedDate = nil }
        } message: {
            if let date = selectedDate {
                Text("This will fill in \(date, format: .dateTime.month(.wide).day()) and use 1 streak saver token. You have \(iapManager.streakSaverTokens) remaining.")
            }
        }
        .confirmationDialog(
            "Delete \(habit.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                modelContext.delete(habit)
                dismiss()
            }
        } message: {
            Text("This will permanently delete this habit and all its history. This cannot be undone.")
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
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

    // MARK: - Stats Row

    private var statsRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                statCard(title: "Streak",  value: "\(habit.currentStreak)", unit: "weeks",     icon: "flame.fill",                     color: .justWarning)
                statCard(title: "Total",   value: "\(habit.totalCompletions)", unit: "days",   icon: "calendar",                       color: habit.displayColor)
                statCard(title: "Rate",    value: "\(Int(habit.weeklyProgress() * 100))%", unit: "this week", icon: "chart.line.uptrend.xyaxis", color: .justSuccess)
            }

            if habit.currentStreak >= 4 {
                Text("You're building something. \(habit.currentStreak) weeks and counting.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else if habit.currentStreak >= 2 {
                Text("Consistency beats intensity. Keep showing up.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func statCard(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Journey Section

    @ViewBuilder
    private var journeySection: some View {
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

    // MARK: - Log Today

    @ViewBuilder
    private var logTodayButton: some View {
        if habit.isInverse {
            inverseLogTodayButton
        } else {
            standardLogTodayButton
        }
    }

    private var standardLogTodayButton: some View {
        let done = habit.isCompleted(on: Date())

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                habit.toggleCompletionAndReloadWidget(on: Date())
            }
            UIImpactFeedbackGenerator(style: habit.isCompleted(on: Date()) ? .medium : .light).impactOccurred()
            // Check for level-up after completing (not uncompleting)
            if habit.isCompleted(on: Date()) && habit.qualifiesForLevelUp() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showLevelUp = true
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
                Text(done ? "You showed up today" : "Show up today")
                    .font(.headline)
                    .contentTransition(.interpolate)
            }
            .foregroundColor(done ? .white : habit.displayColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                habit.displayColor.opacity(done ? 1.0 : 0.12),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .animation(.easeInOut(duration: 0.25), value: done)
    }

    @ViewBuilder
    private var inverseLogTodayButton: some View {
        let affirmed = habit.isAffirmed(on: Date())
        let slipped = !habit.isCompleted(on: Date()) // isCompleted inverts for inverse

        if affirmed {
            // Affirmed state
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    habit.undoAffirmAndReloadWidget(on: Date())
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Holding strong!")
                        .font(.headline)
                        .contentTransition(.interpolate)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.justSuccess, in: RoundedRectangle(cornerRadius: 16))
            }
            .animation(.easeInOut(duration: 0.25), value: affirmed)
        } else if slipped {
            // Slipped state
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    habit.undoSlipAndReloadWidget(on: Date())
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                    Text("Slipped today")
                        .font(.headline)
                        .contentTransition(.interpolate)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.justWarning, in: RoundedRectangle(cornerRadius: 16))
            }
            .animation(.easeInOut(duration: 0.25), value: slipped)
        } else {
            // Not interacted — dual buttons
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        habit.affirmDayAndReloadWidget(on: Date())
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title3)
                        Text("I held strong!")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.justSuccess, in: RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        habit.logSlipAndReloadWidget(on: Date())
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                            .font(.title3)
                        Text("I slipped")
                            .font(.headline)
                    }
                    .foregroundColor(.justWarning)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.justWarning.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Contribution Graph

    private var contributionSection: some View {
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
                    selectedDate = date
                    showStreakSaverConfirm = true
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Streak Saver Section

    private var streakSaverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bandage.fill")
                    .foregroundColor(.justWarning)
                Text("Streak Savers")
                    .font(.headline)
                Spacer()
                Text("\(iapManager.streakSaverTokens) remaining")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.justPrimary)
            }

            Text("Tap a missed day on the graph above to fill it in and protect your streak.")
                .font(.caption)
                .foregroundColor(.secondary)

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
        .padding(20)
        .glassCard()
    }

}
