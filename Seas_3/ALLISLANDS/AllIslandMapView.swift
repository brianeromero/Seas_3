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
    @State private var enterZipCodeViewModel: EnterZipCodeViewModel

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

    init(
        viewModel: AppDayOfWeekViewModel,
        enterZipCodeViewModel: EnterZipCodeViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _enterZipCodeViewModel = State(wrappedValue: enterZipCodeViewModel)
        _locationManager = StateObject(wrappedValue: UserLocationMapViewModel())
        _selectedDay = State(initialValue: .monday)
    }

    var body: some View {
        NavigationView {
            VStack {
                if locationManager.userLocation != nil {
                    makeMapView()
                    makeRadiusPicker()
                } else {
                    Text("Fetching user location...")
                        .navigationTitle("Gyms Near Me")
                }
            }
            .navigationTitle("Gyms Near Me")
            .overlay(overlayContentView())
            .onAppear(perform: onAppear)
            .onChange(of: locationManager.userLocation) { newUserLocation in // Use new onChange syntax
                onChangeUserLocation(newUserLocation)
            }
            .onChange(of: equatableRegion) { newRegion in // Use new onChange syntax
                onChangeEquatableRegion(newRegion)
            }
            .onChange(of: selectedRadius) { newRadius in // Use new onChange syntax
                onChangeSelectedRadius(newRadius)
            }
        }
    }

    private func makeMapView() -> some View {
        Map(coordinateRegion: Binding(
            get: { equatableRegion.region },
            set: { equatableRegion.region = $0 }
        ), showsUserLocation: true, annotationItems: pirateMarkers) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                mapAnnotationView(for: marker)
            }
        }
        .frame(height: 400) // Adjust to match EnterZipCodeView
        .padding()
    }

    private func makeRadiusPicker() -> some View {
        RadiusPicker(selectedRadius: $selectedRadius)
            .padding()
    }

    private func overlayContentView() -> some View {
        ZStack {
            if showModal {
                // Use adaptive background for the overlay dimming effect
                Color.primary.opacity(0.2) // Using primary with opacity for adaptive dimming
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
                        selectedAppDayOfWeek: $selectedAppDayOfWeek
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                    // Use system background colors for modal background
                    .background(Color(.systemBackground)) // Adapts to light/dark mode
                    .cornerRadius(10)
                    .padding()
                    .transition(.opacity)
                } else {
                    Text("No Gym Selected")
                        .padding()
                        // Ensure text color also adapts if not default .primary
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
                // --- THIS IS THE KEY CHANGE ---
                .background(Color(.systemBackground)) // Adapts to light/dark mode
                .cornerRadius(5)
                // Text color naturally adapts to .primary, so no explicit change usually needed
                .foregroundColor(.primary) // Explicitly setting to .primary for clarity, though often default
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
                let locationCoordinate = try await MapUtils.fetchLocation(for: address)
                // Create a CLLocation object using the fetched coordinate
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
        // Handle region change
        // You might want to re-filter and update markers here if the map is interactively moved
        updateMarkers(for: newRegion.region) // Ensure markers update when region changes
    }

    private func onChangeSelectedRadius(_ newRadius: Double) {
        if let userLocation = locationManager.userLocation {
            updateRegion(userLocation, radius: newRadius)
        }
    }

    private func updateRegion(_ location: CLLocation, radius: Double) {
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 1609.34,  // Convert miles to meters
            longitudinalMeters: radius * 1609.34
        )
        equatableRegion = EquatableMKCoordinateRegion(region: newRegion)
        // updateMarkers is called by onChangeEquatableRegion which is triggered by this change
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
