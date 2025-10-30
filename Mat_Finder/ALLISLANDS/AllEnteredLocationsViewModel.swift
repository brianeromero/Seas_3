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

        // Start loading
        DispatchQueue.main.async {
            self.isDataLoaded = false
            self.errorMessage = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.dataManager.fetchPirateIslands()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                switch result {
                case .success(let pirateIslands):
                    self.allIslands = pirateIslands
                    self.updatePirateMarkers(with: pirateIslands)

                case .failure(let error):
                    self.errorMessage = "Failed to load pirate islands: \(error.localizedDescription)"
                    print("❌ Error fetching pirate islands: \(error)")
                    self.pirateMarkers = []  // Ensure markers are empty on failure
                    self.region = .automatic // Reset map
                    self.isDataLoaded = true // Done loading even on error
                }
            }
        }
    }

    private func updatePirateMarkers(with islands: [PirateIsland]) {
        print("updatePirateMarkers called with \(islands.count) islands")

        guard !islands.isEmpty else {
            print("No pirate islands available to create markers.")
            self.pirateMarkers = []
            self.region = .automatic
            self.isDataLoaded = true
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

        // Update markers and map region on main thread
        DispatchQueue.main.async {
            self.pirateMarkers = markers
            self.updateRegion()

            // Debug prints
            print("🗺️ pirateMarkers count after fetch: \(self.pirateMarkers.count)")
            self.pirateMarkers.forEach { marker in
                print("📍 \(marker.title ?? "Unknown") - \(marker.coordinate.latitude), \(marker.coordinate.longitude)")
            }

            // ✅ Only set isDataLoaded after markers and region are updated
            self.isDataLoaded = true
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

