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
    @Published var region: MKCoordinateRegion {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    @Published var enteredLocation: CustomMapMarker?
    @Published var pirateIslands: [CustomMapMarker] = []
    @Published var address: String = ""
    @Published var currentRadius: Double = 5.0
    private var cancellables = Set<AnyCancellable>()
    private let geocoder = CLGeocoder()
    private let context: NSManagedObjectContext
    let locationManager = UserLocationMapViewModel()
    private let updateQueue = DispatchQueue(label: "com.example.Seas_3.updateQueue") // Add a private DispatchQueue

    init(context: NSManagedObjectContext) {
        self.context = context
        self.region = MKCoordinateRegion() // Initialize here

        // Combine Publishers to fetch location when address or currentRadius changes
        $address
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] address in
                guard let self = self else { return }
                self.fetchLocation(for: address, selectedRadius: self.currentRadius)
            }
            .store(in: &cancellables)
        
        $currentRadius
            .sink { [weak self] radius in
                guard let self = self else { return }
                self.fetchLocation(for: self.address, selectedRadius: radius)
            }
            .store(in: &cancellables)
        
        // Observe user location updates
        locationManager.$userLocation
            .sink { [weak self] userLocation in
                guard let self = self, let location = userLocation else { return }
                self.updateRegion(location, radius: self.currentRadius)
                self.fetchPirateIslandsNear(location, within: self.currentRadius * 1609.34)
            }
            .store(in: &cancellables)

        locationManager.startLocationServices()
    }

    func fetchLocation(for address: String, selectedRadius: Double) {
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                print("Geocoding error: \(error)")
                return
            }
            guard let placemark = placemarks?.first, let location = placemark.location else {
                print("No locations found.")
                return
            }

            let coordinate = location.coordinate
            self.updateQueue.async { [weak self] in // Perform updates within updateQueue
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: selectedRadius / 69.0, longitudeDelta: selectedRadius / 69.0))
                    self.enteredLocation = CustomMapMarker(id: UUID(), coordinate: coordinate, title: address)
                }
            }

            self.fetchPirateIslandsNear(location, within: selectedRadius * 1609.34)
        }
    }

    func fetchPirateIslandsNear(_ location: CLLocation, within radius: Double) {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()

        let minLat = location.coordinate.latitude - (radius / 69.0)
        let maxLat = location.coordinate.latitude + (radius / 69.0)
        let minLon = location.coordinate.longitude - (radius / 69.0)
        let maxLon = location.coordinate.longitude + (radius / 69.0)

        fetchRequest.predicate = NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", minLat, maxLat, minLon, maxLon)

        do {
            let islands = try context.fetch(fetchRequest)
            let filteredIslands = islands.filter { island in
                let islandLocation = CLLocation(latitude: island.latitude, longitude: island.longitude)
                let distance = islandLocation.distance(from: location)
                return distance <= radius // already in meters
            }

            self.updateQueue.async { [weak self] in // Perform updates within updateQueue
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.pirateIslands = filteredIslands.map { island in
                        CustomMapMarker(
                            id: island.islandID ?? UUID(),
                            coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                            title: island.islandName
                        )
                    }
                }
            }
        } catch {
            print("Error fetching pirate islands: \(error)")
        }
    }

    func updateRegion(_ userLocation: CLLocation, radius: Double) {
        let span = MKCoordinateSpan(latitudeDelta: radius / 69.0, longitudeDelta: radius / 69.0)
        self.updateQueue.async { [weak self] in // Perform updates within updateQueue
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
            }
        }
    }
}
