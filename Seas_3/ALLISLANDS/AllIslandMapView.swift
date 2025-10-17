// AllIslandMapView.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit
import os
import OSLog




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
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: PirateIsland.entity(), sortDescriptors: [])
    private var islands: FetchedResults<PirateIsland>

    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
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

    @Binding var navigationPath: NavigationPath
    
    
    private let log = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seas3",
                                category: "AllIslandMapView")

    init(
        viewModel: AppDayOfWeekViewModel,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        navigationPath: Binding<NavigationPath>
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.enterZipCodeViewModel = enterZipCodeViewModel
        _locationManager = StateObject(wrappedValue: UserLocationMapViewModel.shared)
        _selectedDay = State(initialValue: .monday)
        self._navigationPath = navigationPath
    }

    var body: some View {
        let content = VStack {
            if locationManager.userLocation != nil {
                makeMapView()
                makeRadiusPicker()
            } else {
                Text("Fetching user location...")
                    .onAppear {
                        log.debug("🕐 Showing 'Fetching user location...' — locationManager.userLocation is currently nil.")
                    }
            }
        }

        return content
            .navigationTitle("Gyms Near Me")
            .overlay(overlayContentView())
            .onAppear(perform: onAppear)
            .onChange(of: locationManager.userLocation) { oldValue, newValue in
                log.info("📍 locationManager.userLocation changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
                onChangeUserLocation(newValue)
            }
            .onChange(of: equatableRegion) { oldValue, newValue in
                log.info("🗺️ Region changed from \(oldValue.region.center.latitude),\(oldValue.region.center.longitude) → \(newValue.region.center.latitude),\(newValue.region.center.longitude)")
                onChangeEquatableRegion(newValue)
            }
            .onChange(of: selectedRadius) { oldValue, newValue in
                log.info("🎯 Radius changed from \(oldValue) → \(newValue) miles")
                onChangeSelectedRadius(newValue)
            }
    }



    private func makeMapView() -> some View {
        Map(position: .constant(.region(equatableRegion.region))) {
            UserAnnotation()
            ForEach(pirateMarkers) { marker in
                Annotation(marker.title ?? "", coordinate: marker.coordinate) {
                    mapAnnotationView(for: marker)
                }
            }
        }
        .frame(height: 400)
        .padding()
        .onAppear {
            log.debug("🗺️ Map view appeared with \(pirateMarkers.count) markers.")
        }
    }


    private func makeRadiusPicker() -> some View {
        RadiusPicker(selectedRadius: $selectedRadius)
            .padding()
            .onAppear {
                log.debug("🎚️ RadiusPicker appeared. Current radius = \(selectedRadius)")
            }
    }


    private func overlayContentView() -> some View {
        ZStack {
            if showModal {
                Color.primary.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { showModal = false }

                if let selectedIsland = selectedIsland {
                    IslandModalContainer(
                        selectedIsland: $selectedIsland,
                        viewModel: viewModel,
                        selectedDay: $selectedDay,
                        showModal: $showModal,
                        enterZipCodeViewModel: enterZipCodeViewModel,
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        navigationPath: $navigationPath
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding()
                    .transition(.opacity)
                    .onAppear {
                        log.debug("🧭 Showing modal for island: \(selectedIsland.islandName ?? "Unknown")")
                    }
                } else {
                    Text("No Gym Selected").padding().foregroundColor(.primary)
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
        log.info("👀 ConsolidatedIslandMapView appeared.")

        // Only start location services if we don't already have a location
        if locationManager.userLocation == nil {
            locationManager.startLocationServices()
            log.debug("🚀 Called startLocationServices()")
        } else {
            log.debug("✅ userLocation already available on appear: \(locationManager.userLocation!.coordinate.latitude), \(locationManager.userLocation!.coordinate.longitude)")
            updateRegion(locationManager.userLocation!, radius: selectedRadius)
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
