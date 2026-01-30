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


final class AllEnteredLocationsViewModel: ObservableObject {
    @Published var allIslands: [PirateIsland] = []
    @Published var pirateMarkers: [CustomMapMarker] = []
    @Published var errorMessage: String?
    @Published var isDataLoaded = false
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published private(set) var isClusteringEnabled: Bool = true
    @Published private(set) var displayedMarkers: [CustomMapMarker] = []

    private let dataManager: PirateIslandDataManager
    private var hasSetInitialRegion = false
    private let clusterBreakLatitudeDelta: Double = 0.15
    private let clusterRadiusMiles: Double = 10

    init(dataManager: PirateIslandDataManager) {
        self.dataManager = dataManager
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
                        CustomMapMarker.forPirateIsland(island)
                    }


                    self.isDataLoaded = true
                    
                    if !self.hasSetInitialRegion {
                        self.cameraPosition = .automatic
                        self.hasSetInitialRegion = true
                    }

                    self.updateDisplayedMarkers()

                case .failure(let error):
                    self.errorMessage = "Failed to load pirate islands: \(error.localizedDescription)"
                    self.pirateMarkers = []
                    self.isDataLoaded = true
                    self.updateDisplayedMarkers()
                }
            }
        }
    }

    func setRegionToUserLocation(_ location: CLLocationCoordinate2D) {
        guard !hasSetInitialRegion else { return }
        
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        }
        hasSetInitialRegion = true
    }
    
    func clusteredMarkers(maxIndividualMarkers: Int = 4) -> [CustomMapMarker] {
        if !isClusteringEnabled { return pirateMarkers }
        guard !pirateMarkers.isEmpty else { return [] }

        var clusters: [CustomMapMarker] = []
        var unclustered = pirateMarkers

        while !unclustered.isEmpty {
            let marker = unclustered.removeFirst()
            var clusterGroup = [marker]

            unclustered = unclustered.filter { otherMarker in
                let distance = marker.coordinate.distance(to: otherMarker.coordinate)
                if distance <= clusterRadiusMiles * 1609.34 {
                    clusterGroup.append(otherMarker)
                    return false
                }
                return true
            }

            if clusterGroup.count > maxIndividualMarkers {
                let avgLat = clusterGroup.map { $0.coordinate.latitude }.reduce(0, +) / Double(clusterGroup.count)
                let avgLon = clusterGroup.map { $0.coordinate.longitude }.reduce(0, +) / Double(clusterGroup.count)
                clusters.append(
                    CustomMapMarker.forCluster(
                        at: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                        count: clusterGroup.count
                    )
                )
            } else {
                clusters.append(contentsOf: clusterGroup.map { marker in
                    if let island = marker.pirateIsland {
                        return CustomMapMarker.forPirateIsland(island)
                    } else {
                        return marker
                    }
                })
            }
        }

        return clusters
    }


    // Inside AllEnteredLocationsViewModel
    func updateClusteringMode(with region: MKCoordinateRegion) {
        let newClusteringState = region.span.latitudeDelta > clusterBreakLatitudeDelta
        
        if isClusteringEnabled != newClusteringState {
            isClusteringEnabled = newClusteringState
            updateDisplayedMarkers()
        }
    }

    func updateDisplayedMarkers() {
        withAnimation(.easeInOut) {
            displayedMarkers = clusteredMarkers(maxIndividualMarkers: 4)
        }
    }
    
    
    // ✅ Public logging method
    func logTileInformation() {
        for marker in pirateMarkers {
            print("Marker ID: \(marker.id), Coordinate: \(marker.coordinate), Title: \(marker.title ?? "Unknown")")
        }
    }
}

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2) // distance in meters
    }
}
