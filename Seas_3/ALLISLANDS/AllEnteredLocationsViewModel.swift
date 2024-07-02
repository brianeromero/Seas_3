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
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 50, longitudeDelta: 50))
    @Published var pirateMarkers: [CustomMapMarker] = []
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private var fetchedResultsController: NSFetchedResultsController<PirateIsland>?

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        initializeFetchedResultsController()
    }

    private func initializeFetchedResultsController() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "islandName", ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController?.delegate = self

        fetchPirateIslands()
    }

    func fetchPirateIslands() {
        do {
            try fetchedResultsController?.performFetch()
            if let fetchedObjects = fetchedResultsController?.fetchedObjects {
                updatePirateMarkers(with: fetchedObjects)
            }
        } catch {
            errorMessage = "Failed to fetch pirate islands: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
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
        
        DispatchQueue.main.async { [weak self] in
            self?.pirateMarkers = markers
            self?.updateRegion()
        }
    }

    private func updateRegion() {
        guard !pirateMarkers.isEmpty else { return }

        // Calculate the bounding box that includes all markers
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

        // Create a region with padding around the markers
        let padding = 0.2 // Adjust as needed
        let span = MKCoordinateSpan(latitudeDelta: abs(maxLat - minLat) + padding, longitudeDelta: abs(maxLon - minLon) + padding)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)

        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(center: center, span: span)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if let fetchedObjects = fetchedResultsController?.fetchedObjects as? [PirateIsland] {
            updatePirateMarkers(with: fetchedObjects)
        }
    }

    // MARK: - Logging Methods for Debugging

    private func logFetchRequestConfiguration() {
        guard let fetchRequest = fetchedResultsController?.fetchRequest else { return }
        print("Fetch Request Entity: \(fetchRequest.entityName ?? "Unknown")")
        print("Sort Descriptors: \(fetchRequest.sortDescriptors ?? [])")
        if let predicate = fetchRequest.predicate {
            print("Predicate: \(predicate)")
        } else {
            print("Predicate: None")
        }
    }

    func logTileInformation() {
        for marker in pirateMarkers {
            print("Marker ID: \(marker.id), Coordinate: \(marker.coordinate), Title: \(marker.title)")
        }
    }
}
