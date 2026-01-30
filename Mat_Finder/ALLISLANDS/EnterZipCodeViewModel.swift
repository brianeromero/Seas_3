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
    
    @Published var currentRadius: Double = 5.0 {
        didSet {
            if let location = locationManager.userLocation {
                updateRegion(location, radius: currentRadius)
                fetchPirateIslandsNear(location, within: currentRadius * 1609.34)
            }
        }
    }

    // MARK: - Private properties
    private var repository: AppDayOfWeekRepository
    private var context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()
    private let updateQueue = DispatchQueue(label: "com.example.Mat_Finder.updateQueue")
    private let earthRadius = 6371.0088 // km
    // MARK: - Clustering properties

    @Published private(set) var isClusteringEnabled: Bool = true
    @Published private(set) var displayedMarkers: [CustomMapMarker] = []

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
                self.fetchPirateIslandsNear(location, within: self.currentRadius * 1609.34)
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

                await MainActor.run {
                    // Update region
                    self.region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(
                            latitudeDelta: currentRadius / 69.0,
                            longitudeDelta: currentRadius / 69.0
                        )
                    )

                    // Update entered location
                    self.enteredLocation = CustomMapMarker(
                        id: UUID(),
                        coordinate: coordinate,
                        title: address,
                        pirateIsland: nil
                    )

                    // Fetch nearby islands
                    self.fetchPirateIslandsNear(
                        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                        within: currentRadius * 1609.34
                    )
                }
            } catch {
                print("Geocoding error: \(error.localizedDescription)")
            }
        }
    }

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
            let filteredIslands = islands.filter { island in
                let islandLocation = CLLocation(latitude: island.latitude, longitude: island.longitude)
                return islandLocation.distance(from: location) <= radius
            }

            self.pirateIslands = filteredIslands.map { island in
                CustomMapMarker(
                    id: island.islandID ?? UUID(),
                    coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                    title: island.islandName ?? "Unknown Gym",
                    pirateIsland: island
                )
            }

            updateDisplayedMarkers()

        } catch {
            print("Error fetching islands: \(error.localizedDescription)")
        }
    }

    func updateRegion(_ userLocation: CLLocation, radius: Double) {
        let span = MKCoordinateSpan(latitudeDelta: radius / 69.0, longitudeDelta: radius / 69.0)
        self.region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
    }
    
    
    func clusteredMarkers(maxIndividualMarkers: Int = 4) -> [CustomMapMarker] {
        if !isClusteringEnabled { return pirateIslands }
        guard !pirateIslands.isEmpty else { return [] }

        var clusters: [CustomMapMarker] = []
        var unclustered = pirateIslands

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
                clusters.append(contentsOf: clusterGroup)
            }
        }

        return clusters
    }

    func updateClusteringMode(with region: MKCoordinateRegion) {
        let newState = region.span.latitudeDelta > clusterBreakLatitudeDelta

        if isClusteringEnabled != newState {
            isClusteringEnabled = newState
            updateDisplayedMarkers()
        }
    }

    func updateDisplayedMarkers() {
        withAnimation(.easeInOut) {
            displayedMarkers = clusteredMarkers(maxIndividualMarkers: 4)
        }
    }

}

// MARK: - Helper
extension EnterZipCodeViewModel {
    @MainActor
    func updateMarkersForCenter(_ center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        let radiusMeters = MapUtils.estimateVisibleRadius(from: span)

        fetchPirateIslandsNear(
            CLLocation(latitude: center.latitude, longitude: center.longitude),
            within: radiusMeters
        )

        // 👇 Keep the map region synced with what the user is viewing
        self.region = MKCoordinateRegion(center: center, span: span)
    }

}
