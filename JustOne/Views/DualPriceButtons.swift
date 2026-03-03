//
//  DualPriceButtons.swift
//  JustOne
//
//  Side-by-side In-App / Web price buttons with an optional savings badge.
//

import SwiftUI

struct DualPriceButtons: View {
    let storeKitPrice: String
    let webPrice: String?
    let savingsPercent: Int?
    let onStoreKit: () -> Void
    let onWeb: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // In-App button (bordered, no fill)
            Button(action: onStoreKit) {
                VStack(spacing: 2) {
                    Text(storeKitPrice)
                        .font(.subheadline.weight(.bold))
                    Text("In-App")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(uiColor: .separator), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            // Web button (gradient fill) — only shown when webPrice exists
            if let webPrice {
                Button(action: onWeb) {
                    VStack(spacing: 2) {
                        Text(webPrice)
                            .font(.subheadline.weight(.bold))
                        Text("Web")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LinearGradient.savingsGradient, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .overlay(alignment: .topTrailing) {
                    if let savingsPercent, savingsPercent > 0 {
                        Text("Save \(savingsPercent)%")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.justSuccess, in: Capsule())
                            .offset(x: 6, y: -10)
                    }
                }
            }
        }
    }
}
