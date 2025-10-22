// AllEnteredLocations.swift
// Mat_Finder
//
// Created by Brian Romero on 6/17/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct AllEnteredLocations: View {
    @ObservedObject var viewModel: AllEnteredLocationsViewModel
    @State private var selectedDay: DayOfWeek? = .monday
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    
    @Binding var navigationPath: NavigationPath


    // Modified initializer to accept viewModel and navigationPath
    init(viewModel: AllEnteredLocationsViewModel, navigationPath: Binding<NavigationPath>) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._navigationPath = navigationPath

        // Initialize the internal StateObjects that AllEnteredLocations manages itself
        let sharedPersistenceController = PersistenceController.shared
        let appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: sharedPersistenceController)

        let zipCodeViewModel = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )
        _enterZipCodeViewModel = StateObject(wrappedValue: zipCodeViewModel)

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            repository: appDayOfWeekRepository,
            enterZipCodeViewModel: zipCodeViewModel
        ))
    }


    var body: some View {
        // REMOVED NavigationView to avoid nested navigation stacks within the global NavigationStack
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
                // Use MapCameraPosition from the ViewModel
                Map(position: $viewModel.region) {
                    ForEach(viewModel.pirateMarkers) { marker in
                        if let island = marker.pirateIsland {
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
                    // viewModel.updateRegion() // This is already called by updatePirateMarkers, no need to call again here
                }
            }
        }
        
        .navigationTitle("All Gyms")
        .onAppear {
            // Ensure data is fetched if it hasn't been loaded yet or if there was a previous error
            if !viewModel.isDataLoaded && viewModel.errorMessage == nil {
                print("📍 AllEnteredLocations: Initial fetchPirateIslands triggered.")
                viewModel.fetchPirateIslands()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSyncPirateIslands)) { _ in
            print("📦 AllEnteredLocations: Firestore sync completed. Re-fetching Core Data gyms...")
            viewModel.fetchPirateIslands()
        }
        .sheet(isPresented: $showModal) {
            IslandModalContainer(
                selectedIsland: $selectedIsland,
                viewModel: appDayOfWeekViewModel,
                selectedDay: $selectedDay,
                showModal: $showModal,
                enterZipCodeViewModel: enterZipCodeViewModel,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                navigationPath: $navigationPath
            )
        }

    }

    private func handleIslandTap(island: PirateIsland?) {
        guard let island = island else { return }
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
