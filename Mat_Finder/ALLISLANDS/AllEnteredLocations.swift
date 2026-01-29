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

    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
        let dataManager = PirateIslandDataManager(viewContext: PersistenceController.shared.viewContext)
        self._viewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(dataManager: dataManager))
        let sharedPersistenceController = PersistenceController.shared
        let appDayOfWeekRepository = AppDayOfWeekRepository(persistenceController: sharedPersistenceController)
        let zipCodeVM = EnterZipCodeViewModel(
            repository: appDayOfWeekRepository,
            persistenceController: sharedPersistenceController
        )
        self._enterZipCodeViewModel = StateObject(wrappedValue: zipCodeVM)
        self._appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            repository: appDayOfWeekRepository,
            enterZipCodeViewModel: zipCodeVM
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isDataLoaded {
                ProgressView("Loading Open Mats...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if viewModel.pirateMarkers.isEmpty {
                Text("No Open Mats found.")
                    .padding()
            } else {
                Map(position: $viewModel.cameraPosition) {
                    UserAnnotation()
                    // 🔹 FIXED: clustering now only occurs at 10 miles or greater
                    ForEach(viewModel.clusteredMarkers(maxIndividualMarkers: 4)) { marker in
                        Annotation(marker.title ?? "", coordinate: marker.coordinate) {
                            if let island = marker.pirateIsland {
                                IslandAnnotationView(island: island) {
                                    handleIslandTap(island: island)
                                }
                            } else {
                                clusterView(for: marker)
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("All Gyms")
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
        .onAppear {
            if !viewModel.isDataLoaded && viewModel.errorMessage == nil {
                viewModel.fetchPirateIslands()
            }
            viewModel.logTileInformation()
            userLocationVM.startLocationServices()
        }
        .onReceive(userLocationVM.$userLocation) { location in
            guard let location = location else { return }
            viewModel.setRegionToUserLocation(location.coordinate)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSyncPirateIslands)) { _ in
            viewModel.fetchPirateIslands()
        }
        .floatingModal(isPresented: $showModal) {
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

    private func clusterView(for marker: CustomMapMarker) -> some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.8))
                .frame(width: 40, height: 40)
            Text(marker.title?.isEmpty == false ? marker.title! : "•")
                .foregroundColor(.white)
                .font(.caption)
                .fontWeight(.bold)
        }
        .onTapGesture {
            zoomMap(to: marker)
        }
    }

    private func handleIslandTap(island: PirateIsland?) {
        guard let island = island else { return }
        selectedIsland = island
        showModal = true
    }

    private func zoomMap(to marker: CustomMapMarker) {
        withAnimation(.easeInOut) {
            viewModel.cameraPosition = .region(MKCoordinateRegion(
                center: marker.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }
}
