//
//  HabitDetailView.swift
//  JustOne
//
//  Full detail view for a single habit.
//  Orchestrates hero card, stats, contribution graph,
//  log-today toggle, and streak-saver controls.
//

import SwiftUI
import SwiftData
import UIKit

struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseManager.self) var purchaseManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedDate: Date? = nil
    @State private var showStreakSaverConfirm = false
    @State private var showConsumableShop = false
    @State private var showLevelUp = false
    @State private var showEditJourney = false
    @State private var showConvertToJourney = false
    @State private var showDeleteConfirm = false
    @State private var showRenameAlert = false
    @State private var renameText = ""

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
                    HabitHeroCardView(habit: habit)
                    if habit.isJourney {
                        HabitJourneySection(habit: habit, showLevelUp: $showLevelUp)
                    }
                    if !habit.isInverse {
                        HabitHealthKitCard(habit: habit)
                    }
                    HabitStatsSection(habit: habit)
                    if habit.status == .active {
                        HabitLogTodayButton(habit: habit, showLevelUp: $showLevelUp)
                    }
                    HabitContributionSection(
                        habit: habit,
                        habitHistoryWeeksLabel: habitHistoryWeeksLabel
                    ) { date in
                        selectedDate = date
                        showStreakSaverConfirm = true
                    }
                    HabitStreakSaverControls(showConsumableShop: $showConsumableShop)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                toolbarMenu
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
                    _ = habit.fillMissedDay(on: date, using: purchaseManager)
                }
                selectedDate = nil
            }
            Button("Cancel", role: .cancel) { selectedDate = nil }
        } message: {
            if let date = selectedDate {
                if purchaseManager.hasUnlimitedStreakSavers {
                    Text("This will fill in \(date, format: .dateTime.month(.wide).day()).")
                } else {
                    Text("This will fill in \(date, format: .dateTime.month(.wide).day()) and use 1 streak saver token. You have \(purchaseManager.streakSaverTokens) remaining.")
                }
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
        .alert("Rename Habit", isPresented: $showRenameAlert) {
            TextField("Habit name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    habit.name = trimmed
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some View {
        Menu {
            Button {
                renameText = habit.name
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            if habit.isJourney {
                Button {
                    showEditJourney = true
                } label: {
                    Label("Edit Journey", systemImage: "pencil.line")
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
