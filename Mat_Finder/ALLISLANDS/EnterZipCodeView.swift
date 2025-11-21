import SwiftUI
import CoreLocation
import MapKit
import CoreData

import SwiftUI
import MapKit
import CoreLocation

struct EnterZipCodeView: View {
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @ObservedObject private var userLocationMapViewModel = UserLocationMapViewModel.shared

    @State private var locationInput: String = ""
    @State private var searchResults: [PirateIsland] = []
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    @State private var selectedIsland: PirateIsland? = nil
    @State private var showModal: Bool = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek? = nil
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var selectedRadius: Double = 5.0 // miles
    @State private var searchCancellable: Task<(), Never>? = nil
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationView {
            VStack {
                // Location input
                TextField("Enter Location (Zip Code, Address, City, State)", text: $locationInput)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: locationInput) { _, _ in
                        searchCancellable?.cancel()
                        searchCancellable = Task {
                            try? await Task.sleep(nanoseconds: 750_000_000)
                            if !Task.isCancelled {
                                try? await search()
                            }
                        }
                    }

                // Map View
                mapSection
                    .frame(height: 400)
                    .onReceive(enterZipCodeViewModel.$pirateIslands) { markers in
                        let updatedIslands = markers.compactMap { $0.pirateIsland }
                        self.searchResults = updatedIslands
                    }

                // Radius Picker
                RadiusPicker(selectedRadius: $selectedRadius)
                    .padding(.top)
                    .onChange(of: selectedRadius) { _, _ in
                        searchCancellable?.cancel()
                        searchCancellable = Task {
                            try? await Task.sleep(nanoseconds: 750_000_000)
                            if !Task.isCancelled {
                                try? await search()
                            }
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Enter Location")
                            .font(.title) // Using .title is closer to the image's size for the main title
                            .fontWeight(.bold)
                            .foregroundColor(.primary)

                        Text("(e.g., Disneyland, Rio De Janeiro, Culinary Institute of America)")
                            .font(.caption) // Using .caption or .footnote for the smaller subtitle text
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
        .onAppear {
            print("EnterZipCodeView: onAppear triggered.")

            if let userLocation = userLocationMapViewModel.userLocation {
                print("Using existing user location.")
                updateCamera(to: userLocation.coordinate)
                Task { try? await search() }
            } else {
                print("No user location yet — requesting location.")
                requestUserLocation()
            }
        }
        .onChange(of: userLocationMapViewModel.userLocation) { _, newValue in
            if let location = newValue {
                print("User location updated to \(location.coordinate.latitude), \(location.coordinate.longitude)")
                updateCamera(to: location.coordinate)
                Task { try? await search() }
            }
        }
    }


    // MARK: - Map Section extracted to avoid compile timeout
    private var mapSection: some View {
        IslandMapView(
            viewModel: appDayOfWeekViewModel,
            selectedIsland: $selectedIsland,
            showModal: $showModal,
            selectedAppDayOfWeek: $selectedAppDayOfWeek,
            selectedDay: $selectedDay,
            allEnteredLocationsViewModel: allEnteredLocationsViewModel,
            enterZipCodeViewModel: enterZipCodeViewModel,
            cameraPosition: $cameraPosition,
            searchResults: $searchResults,
            onMapRegionChange: { region in
                enterZipCodeViewModel.updateMarkersForCenter(region.center, span: region.span)
            }
        )
    }

    // MARK: - Helpers

    private func updateCamera(to coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: selectedRadius * 0.01, longitudeDelta: selectedRadius * 0.01)
            )
        )
    }

    private func requestUserLocation() {
        userLocationMapViewModel.requestLocation()
    }

    private func search() async throws {
        let coordinate = try await MapUtils.geocodeAddressWithFallback(locationInput)

        await MainActor.run {
            updateCamera(to: coordinate)
        }

        await MainActor.run {
            enterZipCodeViewModel.fetchPirateIslandsNear(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                within: selectedRadius * 1609.34
            )
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let filtered = enterZipCodeViewModel.pirateIslands
            .compactMap { $0.pirateIsland }
            .filter {
                let marker = CustomMapMarker(
                    id: UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    title: $0.islandName ?? "",
                    pirateIsland: $0
                )
                return marker.distance(from: location) <= selectedRadius * 1609.34
            }

        await MainActor.run {
            searchResults = filtered
        }

        // ✅ Auto-fit camera to show all results
        if !filtered.isEmpty {
            let coordinates = filtered.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }

            let region = MapUtils.calculateRegionToFit(coordinates: coordinates)
            await MainActor.run {
                self.cameraPosition = .region(region)
            }
        }
    }
}
