//
//  WizardReviewStep.swift
//  JustOne
//
//  Step 3 of the Add Habit Wizard: review journey config before creation.
//

import SwiftUI

struct WizardReviewStep: View {
    let name: String
    let selectedIcon: String
    let effectiveColor: Color
    let valueType: JourneyValueType
    let direction: JourneyDirection
    let customUnit: String
    let frequencyPerWeek: Int
    let pacingDays: Int
    let config: JourneyConfig

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Journey summary card
                VStack(spacing: 16) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 36))
                        .foregroundColor(effectiveColor)
                        .frame(width: 64, height: 64)
                        .background(
                            effectiveColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 18)
                        )

                    Text(name)
                        .font(.title3.weight(.bold))

                    let milestoneCount = config.milestones.count

                    Text("Your journey has \(milestoneCount) level\(milestoneCount == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundColor(effectiveColor)

                    // Milestone preview
                    JourneyTimelineView(
                        journeyConfig: config,
                        accentColor: effectiveColor
                    )
                    .padding(.vertical, 8)

                    // Summary text
                    VStack(spacing: 4) {
                        Text("Start at \(config.formattedValue(config.startValue))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Work toward \(config.formattedValue(config.goalValue))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Stepping by \(config.formattedValue(config.increment)) every \(pacingDays) days")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassCard()

                // Details card
                VStack(alignment: .leading, spacing: 12) {
                    detailRow(label: "Type", value: valueType.displayName)
                    detailRow(label: "Direction", value: direction.displayName)
                    detailRow(label: "Frequency", value: "\(frequencyPerWeek)\u{00D7} per week")
                    if valueType == .custom {
                        detailRow(label: "Unit", value: customUnit)
                    }
                }
                .padding(20)
                .glassCard()
            }
            .padding(20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}
