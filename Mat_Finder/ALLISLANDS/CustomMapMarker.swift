//
//  CustomMapMarker.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import CoreLocation
import MapKit


struct CustomMapMarker: Identifiable, Equatable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D
    var count: Int?               // number to show in circle; nil for individual pins
    var title: String?            // subline / callout
    var pirateIsland: PirateIsland?

    // Equatable
    static func == (lhs: CustomMapMarker, rhs: CustomMapMarker) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.count == rhs.count &&
        lhs.title == rhs.title &&
        lhs.pirateIsland == rhs.pirateIsland
    }

    // Factory for individual pin
    static func forPirateIsland(_ island: PirateIsland) -> CustomMapMarker {
        CustomMapMarker(
            id: island.islandID ?? UUID(),
            coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
            count: nil,                   // individual pin, no number
            title: island.islandName,
            pirateIsland: island
        )
    }

    // Factory for cluster
    static func forCluster(at coordinate: CLLocationCoordinate2D, count: Int) -> CustomMapMarker {
        CustomMapMarker(
            id: UUID(),
            coordinate: coordinate,
            count: count,                      // number to display in circle
            title: "\(count) Gyms Nearby",    // subline
            pirateIsland: nil
        )
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        let islandLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return islandLocation.distance(from: location)
    }
}
