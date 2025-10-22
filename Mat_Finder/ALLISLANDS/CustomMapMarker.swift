//
//  CustomMapMarker.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import CoreLocation
import MapKit


struct CustomMapMarker: Identifiable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var pirateIsland: PirateIsland?
    
    // Manual Equatable conformance
    static func == (lhs: CustomMapMarker, rhs: CustomMapMarker) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.title == rhs.title &&
        lhs.pirateIsland == rhs.pirateIsland
    }

    static func forPirateIsland(_ island: PirateIsland) -> CustomMapMarker {
        CustomMapMarker(
            id: island.islandID ?? UUID(),
            coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
            title: island.islandName,
            pirateIsland: island
        )
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        let islandLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return islandLocation.distance(from: location)
    }
}
