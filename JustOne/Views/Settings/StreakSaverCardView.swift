//
//  StreakSaverCardView.swift
//  JustOne
//
//  Shows streak saver token balance with a "Buy More" button
//  linking to the consumable shop.
//

import SwiftUI

struct StreakSaverCardView: View {
    @Environment(PurchaseManager.self) private var purchaseManager
    @Binding var showConsumableShop: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bandage.fill")
                    .foregroundColor(.justWarning)
                Text("Streak Savers")
                    .font(.headline)
                Spacer()
            }

            Text("Protect a streak if you miss a day")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if purchaseManager.hasUnlimitedStreakSavers {
                        HStack(spacing: 6) {
                            Image(systemName: "infinity")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.justWarning)
                            Text("Unlimited")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.justWarning)
                        }
                        Text("subscription active")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(purchaseManager.streakSaverTokens)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.justWarning)
                        Text("tokens available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !purchaseManager.hasUnlimitedStreakSavers {
                    Button { showConsumableShop = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Buy More")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.justWarning, in: Capsule())
                    }
                }
            }
        }
        .padding(20)
        .glassCard()
    }
}
