// AllIslandMapView.swift
// Mat_Finder
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit
import os
import OSLog



// Equatable wrapper for MKCoordinateRegion
// We'll keep this structure to allow programmatic change handlers if needed,
// but the Map view itself will use MapCameraPosition.
struct EquatableMKCoordinateRegion: Equatable {
    var region: MKCoordinateRegion

    static func == (lhs: EquatableMKCoordinateRegion, rhs: EquatableMKCoordinateRegion) -> Bool {
        // Use a small epsilon for floating-point comparison robustness
        let epsilon: CLLocationDegrees = 0.0000001
        return abs(lhs.region.center.latitude - rhs.region.center.latitude) < epsilon &&
               abs(lhs.region.center.longitude - rhs.region.center.longitude) < epsilon &&
               abs(lhs.region.span.latitudeDelta - rhs.region.span.latitudeDelta) < epsilon &&
               abs(lhs.region.span.longitudeDelta - rhs.region.span.longitudeDelta) < epsilon
    }
}

// Default region for initialization
private let defaultRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
)

struct ConsolidatedIslandMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: PirateIsland.entity(), sortDescriptors: [])
    private var islands: FetchedResults<PirateIsland>

    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @StateObject private var viewModel: AppDayOfWeekViewModel
    @ObservedObject private var locationManager: UserLocationMapViewModel

    @State private var selectedRadius: Double = 5.0
    
    // ⬇️ REPLACED: equatableRegion is no longer the map's source of truth.
    // ⭐️ NEW: Use MapCameraPosition for iOS 17 Map.
    @State private var cameraPosition: MapCameraPosition = .region(defaultRegion)
    
    @State private var pirateMarkers: [CustomMapMarker] = []
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var fetchedLocation: CLLocation?

    @Binding var navigationPath: NavigationPath

    private let log = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mat_Finder",
                                category: "AllIslandMapView")

    init(
        viewModel: AppDayOfWeekViewModel,
        enterZipCodeViewModel: EnterZipCodeViewModel,
        navigationPath: Binding<NavigationPath>
    ) {
        // Ensure you initialize all state properties that don't have an initial value declared above
        _viewModel = StateObject(wrappedValue: viewModel)
        self.enterZipCodeViewModel = enterZipCodeViewModel
        _locationManager = ObservedObject(wrappedValue: UserLocationMapViewModel.shared)
        _selectedDay = State(initialValue: .monday)
        self._navigationPath = navigationPath
        
        // This initialization is fine, but you must ensure MapKit types are available.
        // If your target is < iOS 17, you need @available guards. Assuming iOS 17+.
    }

    var body: some View {
        VStack {
            if locationManager.userLocation != nil {
                makeMapView()
                makeRadiusPicker()
            } else {
                ProgressView("Fetching user location…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        log.debug("🕐 Waiting for user location…")
                    }
            }
        }
        .navigationTitle("Gyms Near Me")
        .overlay(overlayContentView())
        .onAppear(perform: onAppear)
        .onChange(of: locationManager.userLocation) { _, newValue in
            onChangeUserLocation(newValue)
        }
        // ❌ REMOVE: This is no longer necessary as Map updates cameraPosition directly
        // .onChange(of: equatableRegion) { _, newValue in
        //     updateMarkers(for: newValue.region)
        // }
        // The marker update logic for the radius change is now inside onChangeSelectedRadius
        .onChange(of: selectedRadius) { _, newValue in
            onChangeSelectedRadius(newValue)
        }
    }

    // MARK: - Map
    // ⭐️ NEW: Map view using the iOS 17 API
    private func makeMapView() -> some View {
        Map(position: $cameraPosition, interactionModes: .all) { // Use $cameraPosition
            
            // ⭐️ NEW: UserAnnotation replaces showsUserLocation: true
            UserAnnotation()
            
            // ⭐️ NEW: Annotation replaces MapAnnotation and uses ForEach
            ForEach(pirateMarkers) { marker in
                Annotation(marker.title ?? "", coordinate: marker.coordinate) {
                    mapAnnotationView(for: marker)
                }
            }
        }
        // ⭐️ NEW: .onMapCameraChange() replaces manual equatableRegion logic for user gestures
        .onMapCameraChange(frequency: .onEnd) { context in
            // This is called when the user stops dragging or pinching the map.
            updateMarkers(for: context.region)
        }
        .frame(height: 400)
        .padding()
        .onAppear {
            log.debug("🗺️ Map view appeared with \(pirateMarkers.count) markers.")
            // Initial marker load is required here or in onAppear()
            updateMarkers(for: cameraPosition.region ?? defaultRegion)
        }
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
                    .onTapGesture { showModal = false }

                if selectedIsland != nil {
                    IslandModalContainer(
                        selectedIsland: $selectedIsland,
                        viewModel: viewModel,
                        selectedDay: $selectedDay,
                        showModal: $showModal,
                        enterZipCodeViewModel: enterZipCodeViewModel,
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        navigationPath: $navigationPath
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.8,
                            height: UIScreen.main.bounds.height * 0.6)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding()
                    .transition(.opacity)
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
    }

    // MARK: - Helpers
    private func onAppear() {
        if locationManager.userLocation == nil {
            locationManager.startLocationServices()
        } else if let loc = locationManager.userLocation {
            updateRegion(loc, radius: selectedRadius)
        }
        // Ensure markers are loaded on initial appear
        updateMarkers(for: cameraPosition.region ?? defaultRegion)
    }

    private func onChangeUserLocation(_ newUserLocation: CLLocation?) {
        guard let newUserLocation else { return }
        // Keep zoom/center synced with user location
        let newRegion = MKCoordinateRegion(
            center: newUserLocation.coordinate,
            latitudinalMeters: selectedRadius * 1609.34,
            longitudinalMeters: selectedRadius * 1609.34
        )
        // ⭐️ UPDATED: Set cameraPosition directly
        cameraPosition = .region(newRegion)
        // No need to manually update markers, as the cameraPosition change
        // will cause a Map redraw and subsequent .onMapCameraChange call (or related update)
        // but for safety/immediacy, call it here too.
        updateMarkers(for: newRegion)
    }

    private func onChangeSelectedRadius(_ newRadius: Double) {
        // Safely get the current center from the cameraPosition
        guard let center = cameraPosition.region?.center else { return }
        
        let newRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: newRadius * 1609.34,
            longitudinalMeters: newRadius * 1609.34
        )
        // ⭐️ UPDATED: Set cameraPosition directly
        cameraPosition = .region(newRegion)
        
        // When radius changes, update markers based on the new, smaller/larger region
        updateMarkers(for: newRegion)
    }

    private func updateRegion(_ location: CLLocation, radius: Double) {
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 1609.34,
            longitudinalMeters: radius * 1609.34
        )
        // ⭐️ UPDATED: Set cameraPosition directly
        cameraPosition = .region(newRegion)
    }

    // This helper remains the same and correctly filters the islands based on the region
    private func updateMarkers(for region: MKCoordinateRegion) {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        // A better filtering approach might be distance-based for accuracy,
        // but this span-based filtering is kept to match your original intent.
        pirateMarkers = islands.filter { island in
            (island.latitude >= minLat && island.latitude <= maxLat) &&
            (island.longitude >= minLon && island.longitude <= maxLon)
        }.map { island in
            CustomMapMarker(
                id: island.islandID ?? UUID(),
                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                title: island.islandName,
                pirateIsland: island
            )
        }
        log.debug("Markers updated. Found \(self.pirateMarkers.count) gyms in region.")
    }
}
