//
//  AllEnteredLocationsViewModel.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/29/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import CoreLocation
import MapKit

final class AllEnteredLocationsViewModel: NSObject, ObservableObject {
    @Published var allIslands: [PirateIsland] = []
    @Published var pirateMarkers: [CustomMapMarker] = []
    @Published var errorMessage: String?
    @Published var isDataLoaded = false
    @Published var region: MapCameraPosition = .automatic

    private let dataManager: PirateIslandDataManager
    private var hasSetInitialRegion = false

    init(dataManager: PirateIslandDataManager) {
        self.dataManager = dataManager
        super.init()
        fetchPirateIslands()
    }

    func fetchPirateIslands() {
        isDataLoaded = false
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.dataManager.fetchPirateIslands()
            DispatchQueue.main.async {
                switch result {
                case .success(let islands):
                    self.allIslands = islands
                    self.pirateMarkers = islands.map { island in
                        CustomMapMarker(
                            id: island.islandID ?? UUID(),
                            coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                            title: island.islandName ?? "Unknown Island",
                            pirateIsland: island
                        )
                    }
                    self.isDataLoaded = true
                    self.setRegionToFitMarkersOrDefault()
                case .failure(let error):
                    self.errorMessage = "Failed to load pirate islands: \(error.localizedDescription)"
                    self.pirateMarkers = []
                    self.region = .automatic
                    self.isDataLoaded = true
                }
            }
        }
    }

    /// Sets the map region to fit all markers if available, otherwise uses a default zoomed-out span
    func setRegionToFitMarkersOrDefault() {
        guard !hasSetInitialRegion else { return }

        if !pirateMarkers.isEmpty {
            let coordinates = pirateMarkers.map { $0.coordinate }
            let mkRegion = MapUtils.calculateRegionToFit(coordinates: coordinates)
            region = .region(mkRegion)
        } else {
            // Default global zoom (~1000 miles)
            let zoomedOutSpan = MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            region = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -95.0), span: zoomedOutSpan))
        }

        hasSetInitialRegion = true
    }

    /// Updates the map region based on user location (if we haven’t set it already)
    func setRegionToUserLocation(_ location: CLLocationCoordinate2D) {
        guard !hasSetInitialRegion else { return }

        let zoomedOutSpan = MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
        region = .region(MKCoordinateRegion(center: location, span: zoomedOutSpan))
        hasSetInitialRegion = true
    }

    func logTileInformation() {
        for marker in pirateMarkers {
            print("Marker ID: \(marker.id), Coordinate: \(marker.coordinate), Title: \(marker.title ?? "Unknown")")
        }
    }

    func getPirateIsland(from marker: CustomMapMarker) -> PirateIsland? {
        marker.pirateIsland
    }
}
