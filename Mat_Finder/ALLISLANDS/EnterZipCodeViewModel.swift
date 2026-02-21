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
    @Published var postalCode: String = ""
    @Published var enteredLocation: CLLocationCoordinate2D?
    @Published var pirateIslands: [PirateIsland] = []
    @Published var address: String = ""
    @Published var currentRadius: Double = 5.0

    private let repository: AppDayOfWeekRepository
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    private let metersPerMile = 1609.34

    let locationManager = UserLocationMapViewModel.shared

    init(
        repository: AppDayOfWeekRepository,
        persistenceController: PersistenceController
    ) {

        self.repository = repository
        self.context = persistenceController.viewContext
        self.region = MKCoordinateRegion(

            center: CLLocationCoordinate2D(
                latitude: 37.7749,
                longitude: -122.4194
            ),

            span: MKCoordinateSpan(
                latitudeDelta: 0.05,
                longitudeDelta: 0.05
            )
        )


        locationManager.$userLocation

            .sink { [weak self] location in

                guard let self,
                      let location else { return }


                self.updateRegion(location)
                self.fetchPirateIslandsNear(
                    location,
                    within: self.currentRadius * self.metersPerMile
                )
            }

            .store(in: &cancellables)


        locationManager.startLocationServices()
    }


    func fetchPirateIslandsNear(
        _ location: CLLocation,
        within radius: Double
    ) {

        let request: NSFetchRequest<PirateIsland> =
            PirateIsland.fetchRequest()


        do {

            let islands =
                try context.fetch(request)


            self.pirateIslands =
                islands.filter {

                    CLLocation(
                        latitude: $0.latitude,
                        longitude: $0.longitude
                    )
                    .distance(from: location)
                    <= radius
                }

        }
        catch {

            print(error)
        }
    }


    func updateRegion(_ location: CLLocation) {

        region = MKCoordinateRegion(

            center: location.coordinate,

            span: MKCoordinateSpan(
                latitudeDelta: 0.05,
                longitudeDelta: 0.05
            )
        )
    }


    func userDidMoveMap(
        to region: MKCoordinateRegion
    ) {

        self.region = region


        fetchPirateIslandsNear(

            CLLocation(
                latitude: region.center.latitude,
                longitude: region.center.longitude
            ),

            within: currentRadius * metersPerMile
        )
    }
}
