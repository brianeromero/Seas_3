//
//  AllEnteredLocationsViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 6/29/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import CoreLocation
import MapKit

class AllEnteredLocationsViewModel: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var allIslands: [PirateIsland] = []
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @Published var pirateMarkers: [CustomMapMarker] = []
    @Published var errorMessage: String?

    private let dataManager: PirateIslandDataManager

    init(dataManager: PirateIslandDataManager) {
        self.dataManager = dataManager
        super.init()
        // Consider fetching pirate islands here only if this is a background initialization.
        fetchPirateIslands()
    }

    func fetchPirateIslands() {
        // Ensure that this function is not called from view updates.
        print("Fetching pirate islands...")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.dataManager.fetchPirateIslands()
            switch result {
            case .success(let pirateIslands):
                DispatchQueue.main.async {
                    self.allIslands = pirateIslands
                    self.updatePirateMarkers(with: pirateIslands)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch pirate islands: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updatePirateMarkers(with islands: [PirateIsland]) {
        let markers = islands.map { island in
            CustomMapMarker(
                id: island.islandID ?? UUID(),
                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                title: island.islandName
            )
        }

        DispatchQueue.main.async {
            self.pirateMarkers = markers
            self.updateRegion()
        }
    }

    private func updateRegion() {
        guard !pirateMarkers.isEmpty else { return }

        var minLat = pirateMarkers.first!.coordinate.latitude
        var maxLat = pirateMarkers.first!.coordinate.latitude
        var minLon = pirateMarkers.first!.coordinate.longitude
        var maxLon = pirateMarkers.first!.coordinate.longitude

        for marker in pirateMarkers {
            let lat = marker.coordinate.latitude
            let lon = marker.coordinate.longitude
            if lat < minLat { minLat = lat }
            if lat > maxLat { maxLat = lat }
            if lon < minLon { minLon = lon }
            if lon > maxLon { maxLon = lon }
        }

        let padding = 0.2
        let span = MKCoordinateSpan(latitudeDelta: abs(maxLat - minLat) + padding, longitudeDelta: abs(maxLon - minLon) + padding)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)

        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(center: center, span: span)
        }
    }

    // MARK: - Logging Methods for Debugging

    private func logFetchRequestConfiguration() {
        // This method is no longer needed if using dataManager
    }

    func logTileInformation() {
        for marker in pirateMarkers {
            print("Marker ID: \(marker.id), Coordinate: \(marker.coordinate), Title: \(marker.title)")
        }
    }
}
