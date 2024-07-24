//
//  pIslandScheduleView.swift
//  Seas_3
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
                Text("Schedules for \(selectedIsland.islandName)")
                    .font(.title)
                    .padding()

                // Display a list of days to choose from
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            Button(action: {
                                selectedDay = day
                                viewModel.fetchAppDayOfWeekAndUpdateList(for: selectedIsland, day: day)
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
                    pIslandScheduleListView(day: day, schedules: viewModel.schedules[day] ?? [])
                        .padding()
                }
            } else {
                Text("Select an island")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding()

                // Example list of islands to choose from
                List(viewModel.allIslands, id: \.self) { island in
                    Button(action: {
                        self.selectedIsland = island
                        viewModel.loadSchedules(for: island) // Use loadSchedules instead of fetchSchedules
                    }) {
                        Text(island.islandName)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.fetchPirateIslands()
        }
    }
}

#if DEBUG
struct pIslandScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AppDayOfWeekViewModel(selectedIsland: nil)
        return pIslandScheduleView(viewModel: viewModel)
    }
}
#endif
