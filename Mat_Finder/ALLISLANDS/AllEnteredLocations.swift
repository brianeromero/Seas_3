// AllEnteredLocations.swift
// Mat_Finder
//
// Created by Brian Romero on 6/17/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct AllEnteredLocations: View {

    @StateObject var viewModel: AllEnteredLocationsViewModel
    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @StateObject private var userLocationVM = UserLocationMapViewModel.shared

    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    @Binding var navigationPath: NavigationPath


    // ✅ KEEP YOUR INIT
    init(navigationPath: Binding<NavigationPath>) {

        self._navigationPath = navigationPath

        let dataManager =
            PirateIslandDataManager(
                viewContext: PersistenceController.shared.viewContext
            )

        self._viewModel =
            StateObject(
                wrappedValue:
                    AllEnteredLocationsViewModel(
                        dataManager: dataManager
                    )
            )

        let sharedPersistenceController =
            PersistenceController.shared

        let repo =
            AppDayOfWeekRepository(
                persistenceController:
                    sharedPersistenceController
            )

        let zipVM =
            EnterZipCodeViewModel(
                repository: repo,
                persistenceController:
                    sharedPersistenceController
            )

        self._enterZipCodeViewModel =
            StateObject(wrappedValue: zipVM)

        self._appDayOfWeekViewModel =
            StateObject(
                wrappedValue:
                    AppDayOfWeekViewModel(
                        repository: repo,
                        enterZipCodeViewModel: zipVM
                    )
            )
    }


    // ✅ BODY
    var body: some View {

        VStack {

            if !viewModel.isDataLoaded {

                ProgressView("Loading Open Mats...")
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity)

            }
            else if let error =
                        viewModel.errorMessage {

                Text(error)
                    .foregroundColor(.red)

            }
            else if viewModel.allIslands.isEmpty {

                Text("No Open Mats Found")

            }
            else {

                // ✅ THIS IS THE ONLY THING YOU REPLACED
                IslandMKMapView(
                    islands: viewModel.allIslands,
                    selectedIsland: $selectedIsland,
                    showModal: $showModal,
                    region: currentRegion
                )
                .id(viewModel.allIslands.map(\.objectID))
            }
        }


        // ✅ KEEP TOOLBAR
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItem(
                placement: .principal
            ) {

                Text("All Gyms")
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }


        // ✅ KEEP MODAL
        .floatingModal(isPresented: $showModal) {

            IslandModalContainer(
                selectedIsland: $selectedIsland,
                viewModel: appDayOfWeekViewModel,
                selectedDay: $selectedDay,
                showModal: $showModal,
                enterZipCodeViewModel:
                    enterZipCodeViewModel,
                selectedAppDayOfWeek:
                    $selectedAppDayOfWeek,
                navigationPath:
                    $navigationPath
            )
        }


        // ✅ KEEP APPEAR
        .onAppear {

            if !viewModel.isDataLoaded {

                viewModel.fetchPirateIslands()
            }

            userLocationVM.startLocationServices()
        }


        // ✅ KEEP LOCATION UPDATE
        .onReceive(
            userLocationVM.$userLocation
        ) { location in

            guard let location else { return }

            viewModel.setRegionToUserLocation(
                location.coordinate
            )
        }


        // ✅ KEEP SYNC
        .onReceive(
            NotificationCenter.default.publisher(
                for: .didSyncPirateIslands
            )
        ) { _ in

            viewModel.fetchPirateIslands()
        }
    }
    
    private var currentRegion: MKCoordinateRegion {
        viewModel.cameraPosition.region ?? defaultRegion

    }
    
    private let defaultRegion = MKCoordinateRegion(

        center: CLLocationCoordinate2D(
            latitude: 37.7749,
            longitude: -122.4194
        ),

        span: MKCoordinateSpan(
            latitudeDelta: 0.5,
            longitudeDelta: 0.5
        )
    )
}

// MARK: - IslandAnnotationView

struct IslandAnnotationView: View {
    let island: PirateIsland
    let handleIslandTap: () -> Void

    var body: some View {
        Button(action: handleIslandTap) {
            VStack(spacing: 4) {
                Text(island.islandName ?? "Unnamed Gym")
                    .font(.caption2)
                    .padding(4)
                    // --- KEY CHANGE HERE for background ---
                    .background(Color(.systemBackground).opacity(0.85)) // Use adaptive system background
                    .cornerRadius(4)
                    // --- KEY CHANGE HERE for foreground text color ---
                    .foregroundColor(.primary) // Use adaptive primary text color

                CustomMarkerView()
            }
            .shadow(radius: 3)
        }
    }
}

