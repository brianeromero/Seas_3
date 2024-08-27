//
//  ScheduledMatTimesSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/26/24.
//

import Foundation
import SwiftUI

struct ScheduledMatTimesSection: View {
    @Binding var matTimesForDay: [DayOfWeek: [MatTime]]
    @Binding var selectedDay: DayOfWeek? // Optional

    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            if let day = selectedDay, let matTimes = matTimesForDay[day], !matTimes.isEmpty {
                List {
                    ForEach(matTimes.sorted { $0.time ?? "" < $1.time ?? "" }, id: \.self) { matTime in
                        VStack(alignment: .leading) {
                            Text("Time: \(formatTime(matTime.time ?? "Unknown"))")
                                .font(.headline)
                            HStack {
                                Label("Gi", systemImage: matTime.gi ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(matTime.gi ? .green : .red)
                                Label("NoGi", systemImage: matTime.noGi ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(matTime.noGi ? .green : .red)
                                Label("Open Mat", systemImage: matTime.openMat ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(matTime.openMat ? .green : .red)
                            }
                            if matTime.restrictions {
                                Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            if matTime.goodForBeginners {
                                Text("Good for Beginners")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            if matTime.kids {
                                Text("Kids")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                    }
                }
            } else {
                Text("No mat times available.")
                    .foregroundColor(.gray)
            }
        }
    }

    private func formatTime(_ time: String) -> String {
        if let date = DateFormat.time.date(from: time) {
            return DateFormat.shortTime.string(from: date)
        } else {
            return time
        }
    }
}
