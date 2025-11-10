import SwiftUI
import CoreLocation
import MapKit
import CoreData



struct EnterZipCodeView: View {
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @ObservedObject private var userLocationMapViewModel = UserLocationMapViewModel.shared

    @State private var locationInput: String = ""
    @State private var searchResults: [PirateIsland] = []
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedIsland: PirateIsland? = nil
    @State private var showModal: Bool = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek? = nil
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var selectedRadius: Double = 5.0 // Radius in miles
    
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
                IslandMapView(
                    viewModel: appDayOfWeekViewModel,
                    selectedIsland: $selectedIsland,
                    showModal: $showModal,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedDay: $selectedDay,
                    allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    region: $region,
                    searchResults: $searchResults
                )
                .frame(height: 400)

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

                // Auto-update region to first search result
                .onChange(of: searchResults) { _, _ in
                    if let firstIsland = searchResults.first {
                        self.region.center = CLLocationCoordinate2D(latitude: firstIsland.latitude, longitude: firstIsland.longitude)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .navigationTitle("Enter Location")
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
                region.center = userLocation.coordinate
                Task { try? await search() }
            } else {
                print("No user location yet — requesting location.")
                requestUserLocation()
            }
        }
        .onChange(of: userLocationMapViewModel.userLocation) { _, newValue in
            if let location = newValue {
                print("User location updated to \(location.coordinate.latitude), \(location.coordinate.longitude)")
                region.center = location.coordinate
                Task { try? await search() }
            }
        }
    }

    // MARK: - Helper Methods

    private func requestUserLocation() {
        userLocationMapViewModel.requestLocation()
    }

    private func search() async throws {
        let coordinate = try await MapUtils.geocodeAddressWithFallback(locationInput)

        await MainActor.run {
            self.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: self.selectedRadius * 0.01,
                    longitudeDelta: self.selectedRadius * 0.01
                )
            )
        }

        await MainActor.run {
            self.enterZipCodeViewModel.fetchPirateIslandsNear(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                within: self.selectedRadius * 1609.34
            )
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let filtered = self.enterZipCodeViewModel.pirateIslands.compactMap { $0.pirateIsland }.filter {
            let marker = CustomMapMarker(
                id: UUID(),
                coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                title: $0.islandName ?? "",
                pirateIsland: $0
            )
            return marker.distance(from: location) <= self.selectedRadius * 1609.34
        }

        await MainActor.run {
            self.searchResults = filtered
        }
    }
}
