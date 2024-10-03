//
//  ViewScheduleForIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 8/28/24.
//

import Foundation
import SwiftUI
struct ViewScheduleForIsland: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    let island: PirateIsland
    @State private var shouldReload = false

    var body: some View {
        VStack {
            Text("Schedules for \(island.islandName ?? "Unknown Gym")")
                .font(.title)
                .padding()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        Button(action: {
                            viewModel.selectedDay = day
                        }) {
                            Text(day.displayName)
                                .font(.headline)
                                .foregroundColor(viewModel.selectedDay == day ? .blue : .black)
                                .padding()
                        }
                    }
                }
            }

            VStack {
                if let day = viewModel.selectedDay {
                    if !viewModel.matTimesForDay.isEmpty {
                        ScheduledMatTimesSection(
                            island: island,
                            day: day,
                            viewModel: viewModel,
                            matTimesForDay: $viewModel.matTimesForDay,
                            selectedDay: $viewModel.selectedDay
                        )
                    } else {
                        Text("No mat times available for this day.")
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("Please select a day to view the schedule.")
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            print("Loading schedules for island: \(island.islandName ?? "Unknown")")
            viewModel.loadSchedules(for: island)
            print("Loaded schedules: \(viewModel.matTimesForDay.count) mat times")
        }
    }
}
