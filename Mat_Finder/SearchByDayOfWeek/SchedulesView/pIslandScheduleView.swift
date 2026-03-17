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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(DayOfWeek.allCases) { day in
                            Button {
                                selectedDay = day
                                viewModel.fetchAppDayOfWeekAndUpdateList(
                                    for: selectedIsland,
                                    day: day,
                                    context: viewModel.viewContext
                                )
                            } label: {
                                Text(day.ultraShortDisplayName)
                                    .font(.headline)
                                    .foregroundColor(selectedDay == day ? .blue : .black)
                                    .padding()
                            }
                        }
                    }
                }

                if let day = selectedDay {

                    if let matTimes = viewModel.matTimesForDay[day], !matTimes.isEmpty {

                        List {

                            let sortedMatTimes = matTimes.sorted(by: MatTime.scheduleSort)

                            ForEach(sortedMatTimes, id: \.objectID) { matTime in
                                scheduleRow(matTime)
                            }

                        }

                    } else {

                        Text("No mat times available for \(day.displayName)")
                            .foregroundColor(.gray)
                            .padding()

                    }
                }

            } else {

                Text("Select a Gym")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()

                List(viewModel.allIslands, id: \.objectID) { island in
                    Button {
                        selectedIsland = island
                        Task { await viewModel.loadSchedules(for: island) }
                    } label: {
                        Text(island.islandName ?? "Unknown Gym")
                    }
                }
                .padding()
            }
        }
        .onAppear {
            Task { await viewModel.fetchPirateIslands() }
        }
    }

    // MARK: - Row UI
    @ViewBuilder
    private func scheduleRow(_ matTime: MatTime) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text("Time: \(formatTime(matTime.time ?? "Unknown"))")
                .font(.headline)

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

            if matTime.womensOnly {
                Label("Women’s Only", systemImage: "person.2.fill")
                    .foregroundColor(.pink)
            }

            if matTime.restrictions {
                Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Time Formatting
    func formatTime(_ time: String) -> String {

        if let date = AppDateFormatter.twelveHour.date(from: time) {
            return AppDateFormatter.twelveHour.string(from: date)
        }

        return time
    }
}
