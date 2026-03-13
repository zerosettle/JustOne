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

struct HomeDashboardView: View {
    @Query var habits: [Habit]
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(PurchaseManager.self) var purchaseManager

    @State private var showAddStandard = false
    @State private var showAddJourney = false
    @State private var showPremiumUpsell = false
    @State private var selectedHeatmapDate: Date?
    @State private var levelUpHabit: Habit?
    @State private var habitToDelete: Habit?
    @State private var navigatingHabit: Habit?
    @State private var statsSheetMode: StatsSheetMode?
    @State private var showArchived = false
    @State private var showPreviousDayCatchUp = false
    @Environment(\.scenePhase) private var scenePhase

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
                    HomeHeaderView(
                        user: authViewModel.currentUser,
                        activeHabits: activeHabits,
                        statsSheetMode: $statsSheetMode
                    )
                    .modifier(ClearListRowModifier())

                    AggregatedHeatmapView(
                        activeHabits: activeHabits,
                        selectedDate: $selectedHeatmapDate
                    )
                    .modifier(ClearListRowModifier())
                    .animation(.bouncy, value: selectedHeatmapDate)

                    HabitListSection(
                        visibleHabits: visibleHabits,
                        archivedHabits: archivedHabits,
                        activeHabits: activeHabits,
                        showArchived: showArchived,
                        showPremiumUpsell: $showPremiumUpsell,
                        navigatingHabit: $navigatingHabit,
                        levelUpHabit: $levelUpHabit,
                        habitToDelete: $habitToDelete
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 100)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HomeAddButton(
                            habitCount: habits.count,
                            showAddStandard: $showAddStandard,
                            showAddJourney: $showAddJourney,
                            showPremiumUpsell: $showPremiumUpsell
                        )
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
                                    .accessibilityLabel(showArchived ? "Show active habits" : "Show archived habits")
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
            // SDK PATTERN: warmUpAll() preloads checkout WebViews for every
            // product in the catalog. Creates PaymentIntents in parallel.
            .task {
                if let userId = authViewModel.appleUserID {
                    await CheckoutSheet.warmUpAll(userId: userId)
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

        if lastOpened != nil && lastOpened != today && purchaseManager.isPremium {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let hadIncomplete = activeHabits.contains { !$0.isCompleted(on: yesterday) }
            if hadIncomplete {
                showPreviousDayCatchUp = true
            }
        }
    }
}
