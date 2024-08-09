//
//  DayOfWeekView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct DayOfWeekView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    
    @State private var isSaved = false

    var body: some View {
        NavigationView {
            VStack {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Toggle(day.displayName, isOn: viewModel.binding(for: day))
                        .padding()
                }

                NavigationLink(
                    destination: SavedConfirmationView(),
                    isActive: $isSaved,
                    label: {
                        EmptyView()
                    }
                )
            }
            .onAppear {
                if let island = viewModel.selectedIsland {
                    viewModel.fetchCurrentDayOfWeek(for: island)
                } else {
                    print("No island selected")
                }
            }
            .navigationTitle("Day of Week Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.updateSchedules()
                        isSaved = true
                    }
                }
            }
        }
    }
}

struct DayOfWeekView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext

        // Create a mock PirateIsland instance
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        // Create a mock repository
        let mockRepository = AppDayOfWeekRepository.shared // Assuming this is a singleton

        // Create the view model with the mock data
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: mockRepository,
            viewContext: context
        )

        return DayOfWeekView(viewModel: viewModel, selectedAppDayOfWeek: .constant(nil))
            .environment(\.managedObjectContext, context)
    }
}
