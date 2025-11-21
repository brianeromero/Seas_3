// DayOfWeekSearchView.swift
// Mat_Finder
//
// Created by Brian Romero on 8/21/24.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData
import Combine


struct DayOfWeekSearchView: View {
    @State var selectedIsland: PirateIsland?
    @State var selectedAppDayOfWeek: AppDayOfWeek?
    
    @State private var equatableRegionWrapper = EquatableMKCoordinateRegion(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    
    @State private var navigationPath = NavigationPath()
    @ObservedObject private var userLocationMapViewModel = UserLocationMapViewModel.shared
    @EnvironmentObject var viewModel: AppDayOfWeekViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel
    
    @State private var radius: Double = 10.0
    @State private var errorMessage: String?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal: Bool = false

    var body: some View {
        NavigationView {
            VStack {
                // 🗓️ Day Picker
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { oldValue, newValue in
                        print("selectedDay changed from \(oldValue?.rawValue ?? "nil") to \(newValue?.rawValue ?? "nil")")
                        Task { await dayOfWeekChanged() }
                    }

                // ⚠️ Error View
                ErrorView(errorMessage: $errorMessage)

                // 🗺️ Map
                MapViewContainer(
                    region: $equatableRegionWrapper,
                    appDayOfWeekViewModel: viewModel
                ) { island in
                    handleIslandTap(island: island)
                }

                // 🎯 Radius Picker
                RadiusPicker(selectedRadius: $radius)
                    .onChange(of: radius) { oldValue, newValue in
                        print("RadiusPicker: radius changed from \(oldValue) to \(newValue)")
                        Task { await radiusChanged() }
                    }
            }
            .sheet(isPresented: $showModal) {
                IslandModalContainer(
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    navigationPath: $navigationPath
                )
            }
            .onAppear {
                print("DayOfWeekSearchView: onAppear triggered.")

                // ✅ Try to use existing user location first
                if let userLocation = userLocationMapViewModel.userLocation {
                    print("Using existing user location.")
                    updateRegion(center: userLocation.coordinate)
                    Task { await updateIslandsAndRegion() }
                } else {
                    print("No user location yet — requesting location.")
                    userLocationMapViewModel.requestLocation()
                }
            }
            .onChange(of: userLocationMapViewModel.userLocation) { oldValue, newValue in
                if let location = newValue {
                    print("User location updated to \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    updateRegion(center: location.coordinate)
                    Task { await updateIslandsAndRegion() }
                } else {
                    print("User location is nil.")
                }
            }
            .onChange(of: selectedIsland) { oldValue, newValue in
                print("Selected island changed from \(oldValue?.islandName ?? "nil") to \(newValue?.islandName ?? "nil")")
                updateSelectedIsland(from: newValue)
            }
        }
    }

    
    // MARK: - Helper Methods
    
    private func requestUserLocation() {
        userLocationMapViewModel.requestLocation()
    }
    
    private func dayOfWeekChanged() async {
        await updateIslandsAndRegion()
    }
    
    private func radiusChanged() async {
        await updateIslandsAndRegion()
    }
    
    private func updateSelectedIsland(from newIsland: PirateIsland?) {
        guard let newIsland = newIsland else {
            print("updateSelectedIsland: newIsland is nil.")
            return
        }
        
        if let matchingIsland = viewModel.islandsWithMatTimes.map({ $0.0 }).first(where: { $0.islandID == newIsland.islandID }) {
            selectedIsland = matchingIsland
            print("updateSelectedIsland: Found matching island \(matchingIsland.islandName ?? "") in current selection.")
        } else {
            errorMessage = "Island not found in the current selection."
            print("updateSelectedIsland: Error - Island \(newIsland.islandName ?? "") not found in current selection.")
        }
    }
    
    private func handleIslandTap(island: PirateIsland) {
        selectedIsland = island
        showModal = true
        print("handleIslandTap: Tapped on island \(island.islandName ?? "Unnamed"). Showing modal.")
    }
    
    private func updateIslandsAndRegion() async {
        guard let selectedDay = selectedDay else {
            errorMessage = "Day of week is not selected."
            print("updateIslandsAndRegion: Error - Day of week is not selected.")
            return
        }
        
        print("updateIslandsAndRegion: Fetching islands for day: \(selectedDay)")
        await viewModel.fetchIslands(forDay: selectedDay)
        print("updateIslandsAndRegion: Finished fetching islands. ViewModel has \(viewModel.islandsWithMatTimes.count) islands.")
        
        if let location = userLocationMapViewModel.userLocation {
            updateRegion(center: location.coordinate)
        } else {
            print("updateIslandsAndRegion: User location not available for region update.")
        }
    }
    
    private func updateRegion(center: CLLocationCoordinate2D) {
        print("updateRegion: Updating region around \(center.latitude), \(center.longitude)")
        
        withAnimation {
            equatableRegionWrapper.region = MapUtils.updateRegion(
                markers: viewModel.islandsWithMatTimes.map {
                    CustomMapMarker(
                        id: $0.0.islandID ?? UUID(),
                        coordinate: CLLocationCoordinate2D(latitude: $0.0.latitude, longitude: $0.0.longitude),
                        title: $0.0.islandName ?? "Unnamed Gym",
                        pirateIsland: $0.0
                    )
                },
                selectedRadius: radius,
                center: center
            )
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    @Binding var errorMessage: String?
    
    var body: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
        } else {
            EmptyView()
        }
    }
}



// MARK: - MapViewContainer
struct MapViewContainer: View {
    @Binding var region: EquatableMKCoordinateRegion
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    let handleIslandTap: (PirateIsland) -> Void

    @State private var cameraPosition: MapCameraPosition

    init(
        region: Binding<EquatableMKCoordinateRegion>,
        appDayOfWeekViewModel: AppDayOfWeekViewModel,
        handleIslandTap: @escaping (PirateIsland) -> Void
    ) {
        _region = region
        self.appDayOfWeekViewModel = appDayOfWeekViewModel
        self.handleIslandTap = handleIslandTap
        _cameraPosition = State(initialValue: .region(region.wrappedValue.region))
    }

    var body: some View {
        let currentIslands = appDayOfWeekViewModel.islandsWithMatTimes.map { $0.0 }

        Map(position: $cameraPosition) {
            ForEach(currentIslands) { island in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude), anchor: .center) {
                    IslandAnnotationView(island: island) {
                        handleIslandTap(island)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
        }
        .onChange(of: region) { oldValue, newValue in
            print("MapViewContainer: region changed.")
            cameraPosition = .region(newValue.region)
        }

        .onAppear {
            print("MapViewContainer.onAppear: Map container appeared.")
            print("  - \(currentIslands.count) islands loaded.")
        }
    }
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

