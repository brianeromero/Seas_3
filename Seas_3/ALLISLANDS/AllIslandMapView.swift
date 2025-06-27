// AllIslandMapView.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit

// Equatable wrapper for MKCoordinateRegion
struct EquatableMKCoordinateRegion: Equatable {
    var region: MKCoordinateRegion  // <-- Change from 'let' to 'var'

    static func == (lhs: EquatableMKCoordinateRegion, rhs: EquatableMKCoordinateRegion) -> Bool {
        lhs.region.center.latitude == rhs.region.center.latitude &&
        lhs.region.center.longitude == rhs.region.center.longitude &&
        lhs.region.span.latitudeDelta == rhs.region.span.latitudeDelta &&
        lhs.region.span.longitudeDelta == rhs.region.span.longitudeDelta
    }
}


struct ConsolidatedIslandMapView: View {
    @Environment(\.managedObjectContext) private var viewContext // Injected context
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: []
    ) private var islands: FetchedResults<PirateIsland>

    // CHANGE: Removed @State for enterZipCodeViewModel, now passed directly
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel // CHANGE: Changed to @ObservedObject

    @StateObject private var viewModel: AppDayOfWeekViewModel
    @StateObject private var locationManager: UserLocationMapViewModel

    @State private var selectedRadius: Double = 5.0
    @State private var equatableRegion = EquatableMKCoordinateRegion(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var pirateMarkers: [CustomMapMarker] = []
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var fetchedLocation: CLLocation?

    // CHANGE: Changed from @State to @Binding to receive navigationPath from parent
    @Binding var navigationPath: NavigationPath


    init(
        viewModel: AppDayOfWeekViewModel,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        navigationPath: Binding<NavigationPath> // CHANGE: Add navigationPath to init
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        // CHANGE: No longer wrap enterZipCodeViewModel with @State(wrappedValue:), just assign
        self.enterZipCodeViewModel = enterZipCodeViewModel
        _locationManager = StateObject(wrappedValue: UserLocationMapViewModel())
        _selectedDay = State(initialValue: .monday)
        self._navigationPath = navigationPath // CHANGE: Assign navigationPath binding
    }


    var body: some View {
        // CHANGE: REMOVE NavigationView to prevent nesting
        VStack {
            if locationManager.userLocation != nil {
                makeMapView()
                makeRadiusPicker()
            } else {
                Text("Fetching user location...")
                    // .navigationTitle("Gyms Near Me") // This can be on the VStack
            }
        }
        .navigationTitle("Gyms Near Me") // CHANGE: Apply navigationTitle directly to the VStack
        .overlay(overlayContentView())
        .onAppear(perform: onAppear)
        .onChange(of: locationManager.userLocation) { _, newValue in
            onChangeUserLocation(newValue)
        }
        .onChange(of: equatableRegion) { _, newValue in
            onChangeEquatableRegion(newValue)
        }
        .onChange(of: selectedRadius) { _, newValue in
            onChangeSelectedRadius(newValue)
        }
        // No .sheet here, it should be in the main content if it's a modal,
        // or if it's a NavigationLink, it should push.
        // Your overlayContentView() handles the modal, so sheet is not needed here.
    }

    private func makeMapView() -> some View {
        // NOTE: Map in iOS 17+ prefers MapCameraPosition.
        // If you are using an older version of SwiftUI/iOS, MKCoordinateRegion might still be correct.
        // Assuming iOS 17+ and Map(position: ...), but keeping your MKCoordinateRegion as it implies a binding.
        // If you are using iOS 17+, you'd typically convert equatableRegion.region to MapCameraPosition.
        // Example for iOS 17+:
        // Map(position: .constant(.region(equatableRegion.region)), showsUserLocation: true) { ... }
        // For now, retaining your Map(coordinateRegion: ...) which works on older iOS.
        Map(position: .constant(.region(equatableRegion.region))) {
            UserAnnotation() // ✅ Shows the user's current location

            ForEach(pirateMarkers) { marker in
                Annotation(marker.title ?? "", coordinate: marker.coordinate) {
                    mapAnnotationView(for: marker)
                }
            }
        }
        .frame(height: 400)
        .padding()

    }


    private func makeRadiusPicker() -> some View {
        RadiusPicker(selectedRadius: $selectedRadius)
            .padding()
    }



    private func overlayContentView() -> some View {
        ZStack {
            if showModal {
                Color.primary.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showModal = false
                    }

                if selectedIsland != nil {
                    IslandModalContainer(
                        selectedIsland: $selectedIsland,
                        viewModel: viewModel,
                        selectedDay: $selectedDay,
                        showModal: $showModal,
                        enterZipCodeViewModel: enterZipCodeViewModel,
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        navigationPath: $navigationPath // ✅ Pass the binding here!
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding()
                    .transition(.opacity)
                } else {
                    Text("No Gym Selected")
                        .padding()
                        .foregroundColor(.primary)
                }
            }
        }
        .animation(.easeInOut, value: showModal)
    }

    
    private func mapAnnotationView(for marker: CustomMapMarker) -> some View {
        VStack {
            Text(marker.title ?? "")
                .font(.caption)
                .padding(5)
                .background(Color(.systemBackground))
                .cornerRadius(5)
                .foregroundColor(.primary)
            CustomMarkerView()
                .onTapGesture {
                    if let pirateIsland = marker.pirateIsland {
                        selectedIsland = pirateIsland
                        showModal = true
                    }
                }
        }
        .onAppear {
            print("Annotation view for marker: \(marker)")
        }
    }
    
    private func onAppear() {
        locationManager.startLocationServices()
        if let userLocation = locationManager.userLocation {
            updateRegion(userLocation, radius: selectedRadius)
        }
    }


    private func onChangeUserLocation(_ newUserLocation: CLLocation?) {
        guard let newUserLocation = newUserLocation else { return }
        updateRegion(newUserLocation, radius: selectedRadius)

        let address = "Your Address Here" // This will likely need to be dynamic
        Task {
            do {
                // Assuming MapUtils.fetchLocation returns CLLocationCoordinate2D
                let locationCoordinate = try await MapUtils.fetchLocation(for: address)
                self.fetchedLocation = CLLocation(latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude)

                if let location = self.fetchedLocation {
                    updateRegion(location, radius: selectedRadius)
                }
            } catch {
                print("Error fetching location: \(error)")
            }
        }
    }

    private func onChangeEquatableRegion(_ newRegion: EquatableMKCoordinateRegion) {
        updateMarkers(for: newRegion.region)
    }

    private func onChangeSelectedRadius(_ newRadius: Double) {
        if let userLocation = locationManager.userLocation {
            updateRegion(userLocation, radius: newRadius)
        }
    }


    private func updateRegion(_ location: CLLocation, radius: Double) {
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 1609.34,
            longitudinalMeters: radius * 1609.34
        )
        equatableRegion = EquatableMKCoordinateRegion(region: newRegion)
    }


    private func updateMarkers(for region: MKCoordinateRegion) {
        let radiusInMeters = region.span.latitudeDelta * 111_000  // Approximate meters per degree of latitude
        pirateMarkers = islands.filter { island in
            let islandLocation = CLLocation(latitude: island.latitude, longitude: island.longitude)
            let distance = islandLocation.distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude))
            return distance <= radiusInMeters
        }.map { island in
            CustomMapMarker(
                id: island.islandID ?? UUID(), // Ensure islandID is non-nil or provide default
                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                title: island.islandName,
                pirateIsland: island
            )
        }
        print("Markers updated: \(pirateMarkers)")
    }
}
