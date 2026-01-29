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

    // ✅ Modern camera position (iOS 17+)
    @Published var cameraPosition: MapCameraPosition = .automatic

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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
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
                    
                    // ✅ Automatically frame all markers on the first load
                    if !self.hasSetInitialRegion {
                        self.cameraPosition = .automatic
                        self.hasSetInitialRegion = true
                    }

                case .failure(let error):
                    self.errorMessage = "Failed to load pirate islands: \(error.localizedDescription)"
                    self.pirateMarkers = []
                    self.isDataLoaded = true
                }
            }
        }
    }

    /// Updates the map camera based on user location
    func setRegionToUserLocation(_ location: CLLocationCoordinate2D) {
        // We only want to snap to user location once, or when explicitly requested
        guard !hasSetInitialRegion else { return }
        
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        }
        hasSetInitialRegion = true
    }

    func logTileInformation() {
        for marker in pirateMarkers {
            print("Marker ID: \(marker.id), Coordinate: \(marker.coordinate), Title: \(marker.title ?? "Unknown")")
        }
    }

    func getPirateIsland(from marker: CustomMapMarker) -> PirateIsland? {
        return marker.pirateIsland
    }
    
    // MARK: - Clustering Logic
    
    func clusteredMarkers(radiusInMiles: Double = 10, maxIndividualMarkers: Int = 4) -> [CustomMapMarker] {
        guard !pirateMarkers.isEmpty else { return [] }

        var clusters: [CustomMapMarker] = []
        var unclustered = pirateMarkers

        while !unclustered.isEmpty {
            let marker = unclustered.removeFirst()
            var clusterGroup = [marker]

            unclustered = unclustered.filter { otherMarker in
                let distance = marker.coordinate.distance(to: otherMarker.coordinate)
                if distance <= radiusInMiles * 1609.34 { // convert miles to meters
                    clusterGroup.append(otherMarker)
                    return false
                }
                return true
            }

            if clusterGroup.count > maxIndividualMarkers {
                // Calculate average center for the cluster
                let avgLat = clusterGroup.map { $0.coordinate.latitude }.reduce(0, +) / Double(clusterGroup.count)
                let avgLon = clusterGroup.map { $0.coordinate.longitude }.reduce(0, +) / Double(clusterGroup.count)

                let clusterMarker = CustomMapMarker(
                    id: UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    title: "\(clusterGroup.count) Gyms Nearby",
                    pirateIsland: nil
                )
                clusters.append(clusterMarker)
            } else {
                clusters.append(contentsOf: clusterGroup)
            }
        }
        return clusters
    }
}

// MARK: - Extensions

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2) // distance in meters
    }
}
