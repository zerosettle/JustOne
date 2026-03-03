//
//  CheckoutSheetHeader.swift
//  JustOne
//
//  Shared header used inside every `.checkoutSheet` modifier.
//  Shows a contextual icon, product name, price comparison,
//  and a savings badge when applicable.
//

import SwiftUI
import ZeroSettleKit

struct CheckoutSheetHeader: View {
    let product: ZSProduct

    private var isConsumable: Bool {
        product.type == .consumable
    }

    var body: some View {
        VStack(spacing: 10) {
            icon
                .padding(.top, 12)

            Text(product.displayName)
                .font(.title3.weight(.bold))

            priceRow

            savingsBadge
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var icon: some View {
        if isConsumable {
            Image(systemName: "bandage.fill")
                .font(.system(size: 26))
                .foregroundColor(.justWarning)
                .frame(width: 52, height: 52)
                .background(Color.justWarning.opacity(0.12), in: Circle())
        } else {
            Image(systemName: "crown.fill")
                .font(.system(size: 26))
                .foregroundStyle(LinearGradient.premiumGradient)
                .frame(width: 52, height: 52)
                .background(Color.justPrimary.opacity(0.12), in: Circle())
        }
    }

    // MARK: - Price

    @ViewBuilder
    private var priceRow: some View {
        HStack(spacing: 6) {
            if let webPrice = product.webPrice {
                Text(webPrice.formatted)
                    .font(.headline)
            }

            if let appStorePrice = product.appStorePrice {
                Text(appStorePrice.formatted)
                    .font(.subheadline)
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Savings Badge

    @ViewBuilder
    private var savingsBadge: some View {
        if let savings = product.savingsPercent {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.caption2)
                Text("Save \(savings)%")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.justSuccess, in: Capsule())
        }
    }
}
