//
//  ScheduledMatTimesSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/26/24.
//

import Foundation
import SwiftUI
import CoreData

struct ScheduledMatTimesSection: View {
    let island: PirateIsland
    let day: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var matTimesForDay: [DayOfWeek: [MatTime]]
    @Binding var selectedDay: DayOfWeek?

    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            let matTimes = viewModel.fetchMatTimes(for: self.day)

            Group {
                if !matTimes.isEmpty {
                    MatTimesList(day: day.rawValue.capitalized, matTimes: matTimes)
                } else {
                    Text("No mat times available for \(self.day.rawValue.capitalized) at \(island.islandName ?? "this gym").")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            debugPrintMatTimes(matTimes: viewModel.fetchMatTimes(for: self.day))
        }
    }
}

// Ensure this returns a valid View
struct MatTimesList: View {
    let day: String
    let matTimes: [MatTime]

    var body: some View {
        List {
            ForEach(matTimes, id: \.self) { matTime in
                VStack(alignment: .leading) {
                    if let timeString = matTime.time {
                        Text("Time: \(timeString)")
                            .font(.headline)
                    } else {
                        Text("Time: Unknown")
                            .font(.headline)
                    }
                    HStack {
                        if matTime.gi {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Gi")
                            }
                        }
                        if matTime.noGi {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("NoGi")
                            }
                        }
                        if matTime.openMat {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Open Mat")
                            }
                        }
                    }
                    
                    if matTime.restrictions {
                        Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        if matTime.goodForBeginners {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Good for Beginners")
                            }
                        }
                        if matTime.kids {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Kids Class")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            debugPrintMatTimes(matTimes: matTimes)
        }
    }
}

func debugPrintMatTimes(matTimes: [MatTime]) {
    for matTime in matTimes {
        debugPrint("MatTime: \(matTime.time ?? "Unknown")")
        debugPrint("GI: \(matTime.gi)")
    }
}
