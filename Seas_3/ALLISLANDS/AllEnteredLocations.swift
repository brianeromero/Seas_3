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
    @Environment(\.managedObjectContext) private var viewContext // Automatically gets context from environment
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

        // Initialize the EnterZipCodeViewModel and AppDayOfWeekViewModel
        let zipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: PersistenceController.shared // Use the shared PersistenceController here
        )
        _enterZipCodeViewModel = StateObject(wrappedValue: zipCodeViewModel)

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: zipCodeViewModel // Pass the zip code view model directly
        ))
    }

    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.pirateMarkers.isEmpty {
                    Text("No Open Mats found.")
                        .padding()
                } else {
                    let pirateIslands: [PirateIsland] = viewModel.pirateMarkers.compactMap { location in
                        return viewModel.getPirateIsland(from: location)
                    }
                    
                    Map(coordinateRegion: $viewModel.region, annotationItems: pirateIslands) { island in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude)) {
                            IslandAnnotationView(island: island, handleIslandTap: {
                                handleIslandTap(island: island)
                            })
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
                viewModel.fetchPirateIslands()
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

    private func handleIslandTap(island: PirateIsland) {
        selectedIsland = island
        showModal = true
    }
}

struct AllEnteredLocations_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.viewContext
        return AllEnteredLocations()
            .environment(\.managedObjectContext, context) // Context is automatically passed through environment
            .previewDisplayName("All Entered Locations Preview")
    }
}
