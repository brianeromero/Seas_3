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
                        ForEach(DayOfWeek.allCases) { day in
                            Button(action: {
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
                        viewModel.loadSchedules(for: island)
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

struct pIslandScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        // Initialize AppDayOfWeekRepository with the preview PersistenceController
        let mockRepository = AppDayOfWeekRepository(persistenceController: persistenceController)

        // Initialize AppDayOfWeekViewModel with mock data
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: mockRepository
        )

        return pIslandScheduleView(viewModel: viewModel)
            .environment(\.managedObjectContext, context)
            .previewDisplayName("Pirate Island Schedule Preview")
    }
}
