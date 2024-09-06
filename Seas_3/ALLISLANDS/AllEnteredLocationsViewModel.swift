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
        fetchPirateIslands()  // Fetch pirate islands at initialization
    }
    
    func fetchPirateIslands() {
        print("Fetching gyms...")
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
                    self.errorMessage = "Failed to fetch gyms: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func updatePirateMarkers(with islands: [PirateIsland]) {
        let markers = islands.map { island in
            CustomMapMarker(
                id: island.islandID ?? UUID(),
                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                title: island.islandName ?? "Unknown Island",
                pirateIsland: island
            )
        }

        DispatchQueue.main.async {
            self.pirateMarkers = markers
            self.updateRegion()  // Use dynamic region update
        }
    }
    
    func updateRegion() {
        guard !pirateMarkers.isEmpty else { return }

        // Get coordinates for all markers
        let coordinates = pirateMarkers.map { $0.coordinate }

        // Calculate the region to fit all coordinates
        region = MapUtils.calculateRegionToFit(coordinates: coordinates)
    }
    
    // MARK: - Logging Methods for Debugging
    
    func logTileInformation() {
        for marker in pirateMarkers {
            print("Marker ID: \(marker.id), Coordinate: \(marker.coordinate), Title: \(String(describing: marker.title))")
        }
    }
    
    func getPirateIsland(from marker: CustomMapMarker) -> PirateIsland? {
        return allIslands.first(where: { $0.islandName == marker.title })
    }
}
