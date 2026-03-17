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

        HStack(alignment: .firstTextBaseline, spacing: 16) {

            // TIME COLUMN
            Text(matTime.displayTime)
                .font(.title3)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(minWidth: 90, alignment: .leading)

            // CLASS INFO
            VStack(alignment: .leading, spacing: 8) {

                // Header
                Text(matTime.formattedHeader(includeDay: false))
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

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
                .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
        )

        // Discipline Color Stripe
        .overlay(alignment: .leading) {

            if let disciplineString = matTime.discipline,
               let disciplineEnum = Discipline(rawValue: disciplineString) {

                RoundedRectangle(cornerRadius: 3)
                    .fill(color(for: disciplineEnum.badgeColor))
                    .frame(width: 5)
                    .padding(.vertical, 8)
                    .padding(.leading, 2)
            }
        }

        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Badge Row
    @ViewBuilder
    private var badgeRow: some View {

        FlowStack(spacing: 8) {

            ForEach(matTime.badges) { badge in
                badgeView(badge)
            }
        }
    }

    private func badgeView(_ badge: ClassBadge) -> some View {

        Text(badge.text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color(for: badge.color).opacity(0.15))
            )
            .foregroundColor(color(for: badge.color))
    }

    private func color(for name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "teal": return .teal
        case "purple": return .purple
        case "orange": return .orange
        case "indigo": return .indigo
        case "red": return .red
        case "green": return .green
        case "pink": return .pink
        case "gray": return .gray
        default: return .gray
        }
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
