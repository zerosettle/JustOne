//
//  JourneyTimelineView.swift
//  JustOne
//
//  Horizontal stepping-stone timeline showing journey milestones.
//  Completed milestones are filled, current is highlighted, future are gray.
//

import SwiftUI

struct JourneyTimelineView: View {
    let journeyConfig: JourneyConfig
    let accentColor: Color

    private var milestones: [Double] { journeyConfig.milestones }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { index, value in
                    milestoneNode(index: index, value: value)

                    if index < milestones.count - 1 {
                        connectorLine(afterIndex: index)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Milestone Node

    private func milestoneNode(index: Int, value: Double) -> some View {
        let state = milestoneState(for: index)

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(state.fillColor(accent: accentColor))
                    .frame(width: 28, height: 28)

                if state == .current {
                    Circle()
                        .stroke(accentColor, lineWidth: 2.5)
                        .frame(width: 34, height: 34)
                }

                if state == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            Text(journeyConfig.formattedValue(value))
                .font(.system(size: 10, weight: state == .current ? .semibold : .regular))
                .foregroundColor(state == .future ? .secondary.opacity(0.6) : .primary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    // MARK: - Connector Line

    private func connectorLine(afterIndex index: Int) -> some View {
        let completed = index < journeyConfig.currentLevel

        return Rectangle()
            .fill(completed ? accentColor : Color.secondary.opacity(0.2))
            .frame(width: 24, height: 2)
            .padding(.bottom, 20) // Align with circle center
    }

    // MARK: - State

    private enum MilestoneState {
        case completed, current, future

        func fillColor(accent: Color) -> Color {
            switch self {
            case .completed: return accent
            case .current:   return accent.opacity(0.2)
            case .future:    return Color.secondary.opacity(0.12)
            }
        }
    }

    private func milestoneState(for index: Int) -> MilestoneState {
        if index < journeyConfig.currentLevel { return .completed }
        if index == journeyConfig.currentLevel { return .current }
        return .future
    }
}
