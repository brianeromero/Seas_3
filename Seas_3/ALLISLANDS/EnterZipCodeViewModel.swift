//
//  EnterZipCodeViewModel.swift
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

class EnterZipCodeViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    private var repository: AppDayOfWeekRepository
    private var context: NSManagedObjectContext

    @Published var enteredLocation: CustomMapMarker?
    @Published var pirateIslands: [CustomMapMarker] = []
    @Published var address: String = ""
    @Published var currentRadius: Double = 5.0
    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()
    private let updateQueue = DispatchQueue(label: "com.example.Seas_3.updateQueue")
    let locationManager = UserLocationMapViewModel()

    init(repository: AppDayOfWeekRepository, context: NSManagedObjectContext) {
        self.repository = repository
        self.context = context
        self.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)) // Default to San Francisco
        
        locationManager.$userLocation
            .sink { [weak self] userLocation in
                guard let location = userLocation else { return }
                self?.updateRegion(location, radius: self?.currentRadius ?? 5.0)
                self?.fetchPirateIslandsNear(location, within: self?.currentRadius ?? 5.0 * 1609.34)
            }
            .store(in: &cancellables)

        locationManager.startLocationServices()
    }

    func fetchLocation(for address: String) {
        Task {
            do {
                let coordinate = try await MapUtils.fetchLocation(for: address)
                
                // Handle successful geocoding
                DispatchQueue.main.async {
                    self.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: self.currentRadius / 69.0, longitudeDelta: self.currentRadius / 69.0))
                    self.enteredLocation = CustomMapMarker(id: UUID(), coordinate: coordinate, title: address, pirateIsland: nil)
                    self.fetchPirateIslandsNear(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), within: self.currentRadius * 1609.34)
                }
            } catch {
                print("Geocoding error: \(error.localizedDescription)")
            }
        }
    }

    func fetchPirateIslandsNear(_ location: CLLocation, within radius: Double) {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()

        let earthRadius = 6371.0 // Radius of Earth in kilometers

        let latDelta = radius / earthRadius * (180.0 / .pi)
        let lonDelta = radius / (earthRadius * cos(location.coordinate.latitude * .pi / 180.0)) * (180.0 / .pi)

        let minLat = location.coordinate.latitude - latDelta
        let maxLat = location.coordinate.latitude + latDelta
        let minLon = location.coordinate.longitude - lonDelta
        let maxLon = location.coordinate.longitude + lonDelta

        fetchRequest.predicate = NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", minLat, maxLat, minLon, maxLon)

        do {
            let islands = try context.fetch(fetchRequest)
            let filteredIslands = islands.filter { island in
                let islandLocation = CLLocation(latitude: island.latitude, longitude: island.longitude)
                let distance = islandLocation.distance(from: location)
                return distance <= radius
            }

            DispatchQueue.main.async {
                self.pirateIslands = filteredIslands.map { island in
                    CustomMapMarker(
                        id: island.islandID ?? UUID(),
                        coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                        title: island.islandName ?? "Unknown Gym",
                        pirateIsland: island
                    )
                }
            }
        } catch {
            print("Error fetching islands: \(error.localizedDescription)")
        }
    }


    func updateRegion(_ userLocation: CLLocation, radius: Double) {
        let span = MKCoordinateSpan(latitudeDelta: radius / 69.0, longitudeDelta: radius / 69.0)
        DispatchQueue.main.async {
            self.region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
        }
    }
}
