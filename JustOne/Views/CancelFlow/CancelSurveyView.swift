//
//  CancelSurveyView.swift
//  JustOne
//
//  Survey question views for the cancel flow — renders single-select
//  option lists and free-text input fields.
//

import SwiftUI
import ZeroSettleKit

struct CancelSurveyView: View {
    let question: CancelFlow.Question
    @Binding var selectedOptionId: Int?
    @Binding var freeTextInput: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(question.questionText)
                    .font(.title3.weight(.semibold))

                if !question.isRequired {
                    Text("Optional")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            switch question.questionType {
            case .singleSelect:
                singleSelectView
            case .freeText:
                freeTextView
            }
        }
    }

    // MARK: - Single Select

    private var singleSelectView: some View {
        VStack(spacing: 14) {
            ForEach(question.options) { option in
                let isSelected = selectedOptionId == option.id

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedOptionId = option.id
                    }
                } label: {
                    HStack(spacing: 16) {
                        if let iconName = option.iconName {
                            Image(systemName: iconName)
                                .font(.title3)
                                .foregroundColor(isSelected ? .white : .justPrimary)
                                .frame(width: 48, height: 48)
                                .background(
                                    isSelected ? Color.justPrimary : Color.justPrimary.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label)
                                .font(.body.weight(.medium))
                                .foregroundColor(.primary)

                            Text(option.subtitle ?? hardcodedSubtitle(for: option.label))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.justPrimary)
                            .opacity(isSelected ? 1 : 0)
                    }
                    .padding(20)
                    .glassCard()
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.justPrimary : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(LiquidPressStyle())
            }
        }
    }

    // MARK: - Free Text

    private var freeTextView: some View {
        TextEditor(text: $freeTextInput)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(16)
            .frame(minHeight: 140)
            .glassCard()
    }

    // MARK: - Hardcoded Subtitles

    // Hardcoded subtexts matching the dashboard option order for the marketing video.
    private func hardcodedSubtitle(for label: String) -> String {
        switch label {
        case "It's too expensive":
            return "The price doesn't match the value I'm getting"
        case "I'm not using it enough":
            return "I keep forgetting to open the app"
        case "It's not helping me build habits":
            return "I haven't seen a change in my routine"
        case "Missing a feature I need":
            return "There's something I wish the app could do"
        case "Switching to another app":
            return "I found something that fits me better"
        case "Was just trying it out":
            return "I signed up to explore, not to commit"
        default:
            return ""
        }
    }
}
