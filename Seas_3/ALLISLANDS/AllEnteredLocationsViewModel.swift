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
    
    // MARK: - CHANGE THIS LINE
    // Now uses MapCameraPosition instead of MKCoordinateRegion
    @Published var region: MapCameraPosition = .automatic // .automatic is a good starting point


    @Published var pirateMarkers: [CustomMapMarker] = []
    @Published var errorMessage: String?
    @Published var isDataLoaded = false
    
    private let dataManager: PirateIslandDataManager

    init(dataManager: PirateIslandDataManager) {
        self.dataManager = dataManager
        super.init()
        fetchPirateIslands()
    }

    func fetchPirateIslands() {
        print("Fetching pirate islands...")
        // Set isDataLoaded to false at the beginning of the fetch
        // to show the loading indicator in the view
        DispatchQueue.main.async {
            self.isDataLoaded = false
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.dataManager.fetchPirateIslands()
            DispatchQueue.main.async { [weak self] in // Use [weak self] to avoid retain cycles
                guard let self = self else { return } // Safely unwrap self

                switch result {
                case .success(let pirateIslands):
                    self.allIslands = pirateIslands
                    self.updatePirateMarkers(with: pirateIslands)
                    self.errorMessage = nil // Clear any previous error message
                case .failure(let error):
                    // You need to define 'handleError' or integrate its logic here
                    // Assuming handleError sets self.errorMessage
                    self.errorMessage = "Failed to load pirate islands: \(error.localizedDescription)"
                    print("Error fetching pirate islands: \(error)") // Log the actual error
                }
                self.isDataLoaded = true // Data fetching is complete (success or failure)
            }
        }
    }
    
    private func updatePirateMarkers(with islands: [PirateIsland]) {
        guard !islands.isEmpty else {
            print("No pirate islands available to create markers.")
            self.pirateMarkers = [] // Ensure markers are empty if no islands
            self.updateRegion() // Still update region even if empty to reset map
            return
        }

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
            self.updateRegion() // Update map region after markers are set
        }
    }

    func updateRegion() {
        guard !pirateMarkers.isEmpty else {
            // If no markers, set a default camera position or reset to automatic
            self.region = .automatic
            return
        }

        // Get coordinates for all markers
        let coordinates = pirateMarkers.map { $0.coordinate }

        // Calculate the MKCoordinateRegion to fit all coordinates using your MapUtils
        let mkRegion = MapUtils.calculateRegionToFit(coordinates: coordinates)

        // MARK: - Convert MKCoordinateRegion to MapCameraPosition
        self.region = .region(mkRegion)
    }

    // MARK: - Logging Methods for Debugging

    func logTileInformation() {
        for marker in pirateMarkers {
            print("Marker ID: \(marker.id), Coordinate: \(marker.coordinate), Title: \(marker.title ?? "Unknown")")
        }
    }

    func getPirateIsland(from marker: CustomMapMarker) -> PirateIsland? {
        // This method is used by the View to get the actual PirateIsland from the marker.
        // It's good practice to ensure the 'pirateIsland' property on CustomMapMarker
        // is the source of truth, rather than relying on a separate search.
        return marker.pirateIsland
    }
}

