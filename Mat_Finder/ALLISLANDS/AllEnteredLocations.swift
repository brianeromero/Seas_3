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
    
    @State private var searchText: String = ""
    @State private var showIslandList = false
    
    
    // MARK: INIT
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
    
    
    // MARK: BODY
    var body: some View {

        VStack {

            if !viewModel.isDataLoaded {

                ProgressView("Loading Open Mats...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let error = viewModel.errorMessage {

                Text(error)
                    .foregroundColor(.red)

            } else if viewModel.allIslands.isEmpty {

                Text("No Open Mats Found")

            } else {

                ZStack {

                    IslandMKMapView(
                        islands: viewModel.allIslands,
                        selectedIsland: $selectedIsland,
                        showModal: $showModal,
                        selectedRadius: 5.0,
                        region: currentRegion
                    )

                    MapControlsView(

                        fitAction: {

                            guard
                                let mapView = IslandMKMapView.sharedMapView,
                                let userLocation = userLocationVM.userLocation
                            else { return }

                            let region = MKCoordinateRegion(
                                center: userLocation.coordinate,
                                latitudinalMeters: 3_000_000,
                                longitudinalMeters: 3_000_000
                            )

                            mapView.setRegion(region, animated: true)
                        },

                        listAction: {
                            showIslandList = true
                        },

                        userLocationVM: userLocationVM
                    )
                }
            }
        }
        
        // Switch back to map when a gym is selected
        .onChange(of: selectedIsland) { _, newIsland in
            guard let island = newIsland else { return }

            showIslandList = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                zoomToIsland(island)
            }
        }
        
        // MARK: NAV BAR
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {

            ToolbarItem(placement: .principal) {

                Text("All Gyms")
                    .font(.title)
                    .fontWeight(.bold)
            }
        }
        
        
        // MARK: MODAL
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
        
        .sheet(isPresented: $showIslandList) {

            NavigationStack {

                VStack(spacing: 12) {

                    SearchHeader()

                    SearchBar(text: $searchText)

                    AllGymsListView(
                        islands: viewModel.allIslands,
                        selectedIsland: $selectedIsland,
                        showModal: $showModal,
                        searchText: $searchText
                    )
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        
        
        // MARK: APPEAR
        .onAppear {
            
            if !viewModel.isDataLoaded {
                viewModel.fetchPirateIslands()
            }
            
            userLocationVM.startLocationServices()
        }
        
        
        // MARK: LOCATION
        .onReceive(userLocationVM.$userLocation) { location in
            
            guard let location else { return }
            
            viewModel.setRegionToUserLocation(
                location.coordinate
            )
        }
        
        
        // MARK: SYNC
        .onReceive(
            NotificationCenter.default.publisher(
                for: .didSyncPirateIslands
            )
        ) { _ in
            
            viewModel.fetchPirateIslands()
        }
    }
    
    
    // MARK: REGION
    private var currentRegion: MKCoordinateRegion {
        viewModel.cameraPosition.region ?? defaultRegion
    }
    
    private func zoomToIsland(_ island: PirateIsland) {

        guard let mapView = IslandMKMapView.sharedMapView else { return }

        let coordinate = CLLocationCoordinate2D(
            latitude: island.latitude,
            longitude: island.longitude
        )

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )

        mapView.setRegion(region, animated: true)
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

