//
//  EnterZipCodeViewModel.swift
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

@MainActor
class EnterZipCodeViewModel: ObservableObject {

    // MARK: - Published properties
    @Published var region: MKCoordinateRegion
    @Published var postalCode: String = ""
    @Published var enteredLocation: CustomMapMarker?
    @Published var pirateIslands: [CustomMapMarker] = []
    @Published var address: String = ""
    @Published var currentRadius: Double = 5.0

    @Published private(set) var isClusteringEnabled: Bool = true
    @Published private(set) var displayedMarkers: [CustomMapMarker] = []

    // MARK: - Private properties
    private let repository: AppDayOfWeekRepository
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    private let earthRadius = 6371.0088 // km
    private let metersPerMile = 1609.34

    private let clusterBreakLatitudeDelta: Double = 0.15
    private let clusterRadiusMiles: Double = 10

    // MARK: - Location manager
    let locationManager = UserLocationMapViewModel.shared

    // MARK: - Init
    init(repository: AppDayOfWeekRepository, persistenceController: PersistenceController) {
        self.repository = repository
        self.context = persistenceController.viewContext
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        // Observe user location changes
        locationManager.$userLocation
            .sink { [weak self] userLocation in
                guard let self, let location = userLocation else { return }

                self.updateRegion(location, radius: self.currentRadius)
                self.fetchPirateIslandsNear(
                    location,
                    within: self.currentRadius * self.metersPerMile
                )
            }
            .store(in: &cancellables)

        locationManager.startLocationServices()
    }

    // MARK: - Helpers
    func isValidPostalCode() -> Bool {
        postalCode.count == 5 && postalCode.allSatisfy(\.isNumber)
    }

    func fetchLocation(for address: String) {
        Task {
            do {
                let coordinate = try await MapUtils.geocodeAddressWithFallback(address)

                let newRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: currentRadius / 69.0,
                        longitudeDelta: currentRadius / 69.0
                    )
                )

                self.region = newRegion
                updateClusteringMode(with: newRegion)

                self.enteredLocation = CustomMapMarker(
                    id: UUID(),
                    coordinate: coordinate,
                    title: address,
                    pirateIsland: nil
                )

                fetchPirateIslandsNear(
                    CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    within: currentRadius * metersPerMile
                )

            } catch {
                print("Geocoding error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Data Fetching
    func fetchPirateIslandsNear(_ location: CLLocation, within radius: Double) {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()

        // Bounding box optimization
        let latDelta = radius / earthRadius * (180.0 / .pi)
        let lonDelta = radius / (earthRadius * cos(location.coordinate.latitude * .pi / 180.0)) * (180.0 / .pi)

        let minLat = location.coordinate.latitude - latDelta
        let maxLat = location.coordinate.latitude + latDelta
        let minLon = location.coordinate.longitude - lonDelta
        let maxLon = location.coordinate.longitude + lonDelta

        fetchRequest.predicate = NSPredicate(
            format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f",
            minLat, maxLat, minLon, maxLon
        )

        do {
            let islands = try context.fetch(fetchRequest)

            let filteredIslands = islands.filter {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                    .distance(from: location) <= radius
            }

            pirateIslands = filteredIslands.map {
                CustomMapMarker(
                    id: $0.islandID ?? UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                    title: $0.islandName ?? "Unknown Gym",
                    pirateIsland: $0
                )
            }

            updateDisplayedMarkers()

        } catch {
            print("Error fetching islands: \(error.localizedDescription)")
        }
    }

    // MARK: - Region updates
    func updateRegion(_ userLocation: CLLocation, radius: Double) {
        let span = MKCoordinateSpan(
            latitudeDelta: radius / 69.0,
            longitudeDelta: radius / 69.0
        )

        let newRegion = MKCoordinateRegion(center: userLocation.coordinate, span: span)
        region = newRegion
        updateClusteringMode(with: newRegion)
    }

    // MARK: - Clustering
    func clusteredMarkers(maxIndividualMarkers: Int = 4) -> [CustomMapMarker] {
        guard !pirateIslands.isEmpty else { return [] }
        guard isClusteringEnabled else { return pirateIslands }

        var clusters: [CustomMapMarker] = []
        var unclustered = pirateIslands

        while !unclustered.isEmpty {
            let marker = unclustered.removeFirst()
            var clusterGroup = [marker]

            unclustered.removeAll { other in
                let distance = marker.coordinate.distance(to: other.coordinate)
                if distance <= clusterRadiusMiles * metersPerMile {
                    clusterGroup.append(other)
                    return true
                }
                return false
            }

            if clusterGroup.count > maxIndividualMarkers {
                let avgLat = clusterGroup.map(\.coordinate.latitude).reduce(0, +) / Double(clusterGroup.count)
                let avgLon = clusterGroup.map(\.coordinate.longitude).reduce(0, +) / Double(clusterGroup.count)

                clusters.append(
                    CustomMapMarker.forCluster(
                        at: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                        count: clusterGroup.count
                    )
                )
            } else {
                clusters.append(contentsOf: clusterGroup)
            }
        }

        return clusters
    }

    func updateClusteringMode(with region: MKCoordinateRegion) {
        let newState = region.span.latitudeDelta > clusterBreakLatitudeDelta
        guard newState != isClusteringEnabled else { return }

        isClusteringEnabled = newState
        updateDisplayedMarkers()
    }

    func updateDisplayedMarkers() {
        withAnimation(.easeInOut) {
            displayedMarkers = clusteredMarkers(maxIndividualMarkers: 4)
        }
    }

    // MARK: - Map interaction
    func updateMarkersForCenter(_ center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        let radiusMeters = MapUtils.estimateVisibleRadius(from: span)
        fetchPirateIslandsNear(
            CLLocation(latitude: center.latitude, longitude: center.longitude),
            within: radiusMeters
        )
    }

    func userDidMoveMap(to region: MKCoordinateRegion) {
        self.region = region
        updateClusteringMode(with: region)
        updateMarkersForCenter(region.center, span: region.span)
    }
}
