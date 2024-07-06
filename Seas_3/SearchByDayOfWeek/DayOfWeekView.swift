//
//  DayOfWeekView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct DayOfWeekView: View {
    @StateObject var viewModel: AppDayOfWeekViewModel
    @State private var isSaved = false

    init(selectedIsland: PirateIsland?, repository: AppDayOfWeekRepository = AppDayOfWeekRepository.shared) {
        _viewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(selectedIsland: selectedIsland, repository: repository))
    }

    var body: some View {
        NavigationView {
            VStack {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Toggle(day.displayName, isOn: viewModel.binding(for: day))
                }

                Button("Save Day of Week") {
                    viewModel.saveAllSchedules()
                    isSaved = true
                }
                .padding()

                NavigationLink(
                    destination: SavedConfirmationView(),
                    isActive: $isSaved,
                    label: {
                        EmptyView()
                    }
                )
            }
            .onAppear {
                viewModel.fetchCurrentDayOfWeek()
                Logger.log("View appeared", view: "DayOfWeekView")
            }
            .navigationTitle("Day of Week Settings")
        }
    }
}

struct DayOfWeekView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "")

        return DayOfWeekView(selectedIsland: mockIsland)
            .environment(\.managedObjectContext, context)
    }
}
