//
//  pIslandScheduleListView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/12/24.
//

import SwiftUI
import SwiftUI

struct pIslandScheduleListView: View {

    let day: DayOfWeek
    let schedules: [MatTime]

    var body: some View {

        VStack {

            Text("Schedules for \(day.displayName)")
                .font(.title)
                .padding()

            List {

                let sorted = schedules.sorted(by: MatTime.scheduleSort)

                ForEach(sorted, id: \.objectID) { matTime in

                    VStack(alignment: .leading, spacing: 8) {

                        HStack {

                            Text(formatTime(matTime.time ?? "Unknown"))
                                .font(.headline)

                            Spacer()

                            if matTime.goodForBeginners {
                                Text("Beginner")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }

                        // Badge system
                        HStack(spacing: 6) {

                            ForEach(matTime.badges) { badge in
                                Text(badge.text)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(badge.color))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }

                        if matTime.restrictions {
                            Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    func formatTime(_ time: String) -> String {

        if let date = AppDateFormatter.twelveHour.date(from: time) {
            return AppDateFormatter.twelveHour.string(from: date)
        }

        return time
    }
}
struct ScheduleRow: View {

    let matTime: MatTime

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(matTime.time ?? "No time set")
                .font(.body)

            HStack(spacing: 6) {

                ForEach(matTime.badges) { badge in
                    Text(badge.text)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(badge.color))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            if matTime.goodForBeginners {
                Text("Good for Beginners")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            if matTime.restrictions {
                Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 5)
    }
}
