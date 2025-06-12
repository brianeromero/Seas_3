// AllEnteredLocations.swift
// Seas2
//
// Created by Brian Romero on 6/17/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct AllEnteredLocations: View {
    @State private var selectedDay: DayOfWeek? = .monday
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: AllEnteredLocationsViewModel
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    init() {
        _viewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(
            dataManager: PirateIslandDataManager(viewContext: PersistenceController.shared.viewContext)
        ))

        let zipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: PersistenceController.shared
        )
        _enterZipCodeViewModel = StateObject(wrappedValue: zipCodeViewModel)

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: zipCodeViewModel
        ))
    }

    var body: some View {
        NavigationView {
            VStack {
                if !viewModel.isDataLoaded {
                    ProgressView("Loading Open Mats...")
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.pirateMarkers.isEmpty {
                    Text("No Open Mats found.")
                        .padding()
                } else {
                    // **THIS IS THE CRITICAL CHANGE**
                    // Use the new Map initializer that takes a content closure
                    Map(position: $viewModel.region) { // Use MapCameraPosition if you prefer
                        ForEach(viewModel.pirateMarkers) { marker in
                            if let island = marker.pirateIsland { // This line is crucial and correct
                                Annotation(marker.title ?? "Unknown Island", coordinate: marker.coordinate) {
                                    IslandAnnotationView(island: island, handleIslandTap: {
                                        handleIslandTap(island: island)
                                    })
                                }
                                .annotationTitles(.hidden)
                            }
                        }
                    }
                    .onAppear {
                        viewModel.logTileInformation()
                        viewModel.updateRegion()
                    }
                }
            }
            .navigationTitle("All Gyms")
            .onAppear {
                // ViewModel's init already calls fetchPirateIslands()
            }
            .sheet(isPresented: $showModal) {
                IslandModalContainer(
                    selectedIsland: $selectedIsland,
                    viewModel: appDayOfWeekViewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek
                )
            }
        }
    }

    private func handleIslandTap(island: PirateIsland?) { // Note the optional for island
        guard let island = island else { return } // Safely unwrap
        selectedIsland = island
        showModal = true
    }
}

/*
struct AllEnteredLocations_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.viewContext
        return AllEnteredLocations()
            .environment(\.managedObjectContext, context) // Context is automatically passed through environment
            .previewDisplayName("All Entered Locations Preview")
    }
}
*/
