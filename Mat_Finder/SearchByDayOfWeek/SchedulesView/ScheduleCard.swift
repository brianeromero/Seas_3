//
//  ScheduleCard.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/3/26.
//

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

        HStack(alignment: .top, spacing: 16) {

            // TIME COLUMN
            Text(displayTime)
                .font(.title3)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(minWidth: 90, alignment: .leading)
            
            // CLASS INFO
            VStack(alignment: .leading, spacing: 8) {

                // Header
                Text(matTime.formattedHeader(includeDay: false))
                    .font(.headline)

                // Badges
                badgeRow

                // Beginner Friendly
                if matTime.goodForBeginners {
                    Label("Beginner Friendly", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Restrictions
                if matTime.restrictions {

                    HStack(spacing: 6) {

                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        Text(
                            matTime.restrictionDescription?.isEmpty == false
                            ? matTime.restrictionDescription!
                            : "Restrictions"
                        )
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        )
    }

    // MARK: - Badge Row
    @ViewBuilder
    private var badgeRow: some View {

        FlowStack(spacing: 8) {

            if matTime.womensOnly {
                badge("Women's", color: .pink)
            }

            if matTime.kids {
                badge("Kids", color: .green)
            }

            if matTime.openMat {
                badge("Open Mat", color: .purple)
            }

            if matTime.gi {
                badge("Gi", color: .gray)
            }

            if matTime.noGi {
                badge("NoGi", color: .red)
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {

        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .foregroundColor(color)
    }
    
    private var displayTime: String {

        guard let time = matTime.time,
              let date = AppDateFormatter.stringToDate(time) else {
            return matTime.time ?? ""
        }

        return AppDateFormatter.twelveHour.string(from: date)
    }
}

struct FlowLayout: Layout {

    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {

        let maxWidth = proposal.width ?? 0

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {

            let size = view.sizeThatFits(.unspecified)

            if x + size.width > maxWidth {

                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {

        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {

            let size = view.sizeThatFits(.unspecified)

            if x + size.width > bounds.maxX {

                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            view.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )

            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

struct FlowStack<Content: View>: View {

    var spacing: CGFloat = 6
    let content: () -> Content

    init(spacing: CGFloat = 6, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: spacing) {
            content()
        }
    }
}
