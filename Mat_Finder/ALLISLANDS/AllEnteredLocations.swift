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
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    @Binding var navigationPath: NavigationPath

    // MARK: - Modified initializer
    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath

        // 1️⃣ Create the DataManager using the shared Core Data context
        let dataManager = PirateIslandDataManager(viewContext: PersistenceController.shared.viewContext)

        // 2️⃣ Create the main ViewModel with that data manager
        let mainViewModel = AllEnteredLocationsViewModel(dataManager: dataManager)
        self._viewModel = ObservedObject(wrappedValue: mainViewModel)

        // 3️⃣ Initialize the StateObjects for other view models
        let sharedPersistenceController = PersistenceController.shared
        let appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: sharedPersistenceController)

        let zipCodeVM = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )
        _enterZipCodeViewModel = StateObject(wrappedValue: zipCodeVM)

        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            repository: appDayOfWeekRepository,
            enterZipCodeViewModel: zipCodeVM
        ))
    }

    var body: some View {
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
                Map(position: $viewModel.region) {
                    ForEach(viewModel.pirateMarkers) { marker in
                        if let island = marker.pirateIsland {
                            Annotation(marker.title ?? "Unknown Island", coordinate: marker.coordinate) {
                                IslandAnnotationView(island: island) {
                                    handleIslandTap(island: island)
                                }
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                }
                .onAppear { viewModel.logTileInformation() }
            }
        }
        .navigationTitle("All Gyms")
        .onAppear {
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
