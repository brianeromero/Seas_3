// IslandMapView.swift
// Mat_Finder
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation
import MapKit


// MARK: - IslandMapView (Modern Map API)
struct IslandMapView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedDay: DayOfWeek?
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel

    // Modern MapKit API bindings
    @Binding var cameraPosition: MapCameraPosition
    @Binding var searchResults: [PirateIsland]

    var onMapRegionChange: (MKCoordinateRegion) -> Void

    @State private var navigationPath = NavigationPath()
    @State private var mapUpdateTask: Task<(), Never>? = nil

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(searchResults, id: \.islandID) { island in
                Annotation(
                    "", // empty string, nothing will show
                    coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                    anchor: .center
                ) {
                    AnnotationMarkerView(island: island, handleTap: handleTap)
                }
            }
        }
        .frame(height: 400)
        .edgesIgnoringSafeArea(.all)
        .onMapCameraChange(frequency: .continuous) { context in
            let region = context.region
            mapUpdateTask?.cancel()
            mapUpdateTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        // Directly update markers for current center + span
                        enterZipCodeViewModel.updateMarkersForCenter(region.center, span: region.span)
                    }
                }
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
    }

    private func handleTap(island: PirateIsland) {
        selectedIsland = island
        showModal = true
    }
}

// MARK: - AnnotationMarkerView (Custom Marker)
struct AnnotationMarkerView: View {
    let island: PirateIsland
    let handleTap: (PirateIsland) -> Void

    var body: some View {
        VStack {
            Text(island.islandName ?? "Unknown Title")
                .font(.caption)
                .padding(5)
                .background(Color(.systemBackground))
                .cornerRadius(5)
                .foregroundColor(.primary)
            CustomMarkerView()
        }
        .onTapGesture {
            handleTap(island)
        }
    }
}

// MARK: - IslandMapViewMap (For Single Island)
struct IslandMapViewMap: View {
    // ✅ Use the modern API as well for consistency
    @State private var cameraPosition: MapCameraPosition
    var coordinate: CLLocationCoordinate2D
    var islandName: String
    var islandLocation: String
    var onTap: (PirateIsland) -> Void
    var island: PirateIsland
    @State private var showConfirmationDialog = false

    init(
        coordinate: CLLocationCoordinate2D,
        islandName: String,
        islandLocation: String,
        onTap: @escaping (PirateIsland) -> Void,
        island: PirateIsland
    ) {
        self.coordinate = coordinate
        self.islandName = islandName
        self.islandLocation = islandLocation
        self.onTap = onTap
        self.island = island

        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            Annotation(
                "", // empty string — satisfies compiler, nothing is shown by MapKit
                coordinate: coordinate,
                anchor: .center
            ) {
                VStack {
                    Text(islandName)
                        .font(.caption)
                        .padding(5)
                        .background(Color(.systemBackground))
                        .cornerRadius(5)
                        .foregroundColor(.primary)
                    CustomMarkerView()
                }
                .onTapGesture {
                    onTap(island)
                    showConfirmationDialog = true
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .alert(isPresented: $showConfirmationDialog) {
            Alert(
                title: Text("Open in Maps?"),
                message: Text("Do you want to open \(islandName) in Maps?"),
                primaryButton: .default(Text("Open")) {
                    ReviewUtils.openInMaps(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        islandName: islandName,
                        islandLocation: islandLocation
                    )
                },
                secondaryButton: .cancel()
            )
        }
    }
}
