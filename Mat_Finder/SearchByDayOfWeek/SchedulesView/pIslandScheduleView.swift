//
//  pIslandScheduleView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/12/24.
//

import SwiftUI

struct pIslandScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @State private var selectedIsland: PirateIsland?
    @State private var selectedDay: DayOfWeek?

    var body: some View {
        VStack {
            if let selectedIsland = selectedIsland {
                Text("Schedules for \(selectedIsland.islandName ?? "Unknown Gym")")
                    .font(.title)
                    .padding()

                // Display a list of days to choose from
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(DayOfWeek.allCases) { day in
                            Button(action: {
                                self.selectedDay = day // Update selectedDay
                                viewModel.fetchAppDayOfWeekAndUpdateList(for: selectedIsland, day: day, context: viewModel.viewContext)
                            }) {
                                Text(day.displayName)
                                    .font(.headline)
                                    .foregroundColor(selectedDay == day ? .blue : .black)
                                    .padding()
                            }
                        }
                    }
                }

                // Display schedules for the selected day
                if let day = selectedDay {
                    if let matTimes = viewModel.matTimesForDay[day], !matTimes.isEmpty {
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
                                        Text("Kids Class")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                            }
                        }
                    } else {
                        Text("No mat times available for1 \(day.displayName)")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            } else {
                Text("Select a Gym")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()

                // Example list of islands to choose from
                List(viewModel.allIslands, id: \.self) { island in
                    Button(action: {
                        self.selectedIsland = island
                        Task {
                            await viewModel.loadSchedules(for: island)
                        }
                    }) {
                        Text(island.islandName ?? "Unknown Gym")
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.fetchPirateIslands()
        }
    }

    // Function to format time
    func formatTime(_ time: String) -> String {
        if let date = DateFormat.time.date(from: time) {
            return DateFormat.shortTime.string(from: date)
        } else {
            return time
        }
    }
}
