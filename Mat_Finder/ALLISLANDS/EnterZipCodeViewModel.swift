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
    @Published var region: MKCoordinateRegion
    private var repository: AppDayOfWeekRepository
    private var context: NSManagedObjectContext
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

    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()
    private let updateQueue = DispatchQueue(label: "com.example.Mat_Finder.updateQueue")
    let locationManager = UserLocationMapViewModel.shared
    private let earthRadius = 6371.0088 // km

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

    func isValidPostalCode() -> Bool {
        postalCode.count == 5 && postalCode.allSatisfy(\.isNumber)
    }

    func fetchLocation(for address: String) {
        Task {
            do {
                let coordinate = try await MapUtils.geocodeAddressWithFallback(address)

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
        } catch {
            print("Error fetching islands: \(error.localizedDescription)")
        }
    }

    func updateRegion(_ userLocation: CLLocation, radius: Double) {
        let span = MKCoordinateSpan(latitudeDelta: radius / 69.0, longitudeDelta: radius / 69.0)
        self.region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
    }
}
