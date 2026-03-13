//
//  HabitListSection.swift
//  JustOne
//
//  Habits list content for the home dashboard: active/archived rows
//  with swipe actions, context menus, empty states, and the locked
//  ghost card for free users.
//

import SwiftUI
import UIKit

struct HabitListSection: View {
    let visibleHabits: [Habit]
    let archivedHabits: [Habit]
    let activeHabits: [Habit]
    let showArchived: Bool
    @Binding var showPremiumUpsell: Bool
    @Binding var navigatingHabit: Habit?
    @Binding var levelUpHabit: Habit?
    @Binding var habitToDelete: Habit?
    @Environment(PurchaseManager.self) private var purchaseManager

    /// The habits to display based on the current filter.
    private var displayedHabits: [Habit] {
        showArchived ? archivedHabits : visibleHabits
    }

    /// The user's oldest visible habit — the one free slot.
    private var oldestVisibleHabit: Habit? {
        visibleHabits.min(by: { $0.createdAt < $1.createdAt })
    }

    /// Returns `true` when the habit should be locked for non-premium users.
    private func isHabitLocked(_ habit: Habit) -> Bool {
        guard !purchaseManager.isPremium else { return false }
        guard visibleHabits.count > 1 else { return false }
        return habit !== oldestVisibleHabit
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        HStack {
            Text(showArchived ? "Archived Habits" : "Your Habits")
                .font(.headline)
            Spacer()
            if !showArchived && purchaseManager.isPremium {
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
                habitRow(habit)
            }

            if !showArchived && !purchaseManager.isPremium {
                lockedHabitCard
                    .modifier(ClearListRowModifier())
            }
        }
    }

    // MARK: - Habit Row

    private func habitRow(_ habit: Habit) -> some View {
        Button {
            if isHabitLocked(habit) {
                showPremiumUpsell = true
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    navigatingHabit = habit
                }
            }
        } label: {
            HabitRowView(
                habit: habit,
                isLocked: isHabitLocked(habit),
                onToggleToday: {
                    guard !isHabitLocked(habit) else { return }
                    guard habit.status == .active else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        habit.toggleCompletionAndReloadWidget(on: Date())
                    }
                    HapticFeedback.impact(habit.isCompleted(on: Date()) ? .medium : .light)
                    if habit.isCompleted(on: Date()) && habit.qualifiesForLevelUp() {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            levelUpHabit = habit
                        }
                    }
                },
                onAffirmToday: {
                    guard !isHabitLocked(habit) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if habit.isAffirmed(on: Date()) {
                            habit.undoAffirmAndReloadWidget(on: Date())
                        } else {
                            habit.affirmDayAndReloadWidget(on: Date())
                        }
                    }
                    HapticFeedback.impact(.medium)
                },
                onSlipToday: {
                    guard !isHabitLocked(habit) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if !habit.isCompleted(on: Date()) {
                            habit.undoSlipAndReloadWidget(on: Date())
                        } else {
                            habit.logSlipAndReloadWidget(on: Date())
                        }
                    }
                    HapticFeedback.impact(.light)
                }
            )
        }
        .buttonStyle(LiquidPressStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isHabitLocked(habit) {
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
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isHabitLocked(habit) && !showArchived {
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
            if isHabitLocked(habit) {
                Button {
                    showPremiumUpsell = true
                } label: {
                    Label("Unlock with Pro", systemImage: "lock.open.fill")
                }
            } else {
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
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .trailing))
        ))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }

    // MARK: - Empty States

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

    // MARK: - Locked Habit Card

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
}

// MARK: - Row Modifier

struct ClearListRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
    }
}
