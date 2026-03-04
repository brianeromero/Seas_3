//
//  ScheduleCard.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/3/26.
//

import SwiftUI


struct ScheduleCard: View {

    let matTime: MatTime
    let island: PirateIsland

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            // Header
            Text(matTime.formattedHeader(includeDay: false))
                .font(.headline)

            // Time
            Text(matTime.time ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Badges
            badgeRow

            // Beginner Friendly
            if matTime.goodForBeginners {
                Label("Beginner Friendly", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Badge Row

    @ViewBuilder
    private var badgeRow: some View {

        HStack(spacing: 6) {

            if matTime.womensOnly {
                badge("Women's", color: .pink)
            }

            if matTime.kids {
                badge("Kids", color: .blue)
            }

            if matTime.openMat {
                badge("Open Mat", color: .purple)
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}
