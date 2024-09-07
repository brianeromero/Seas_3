//
//  CustomMapMarker.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import CoreLocation
import MapKit

class CustomMapMarker: NSObject, MKAnnotation, Identifiable {
    let id: UUID
    var coordinate: CLLocationCoordinate2D
    var title: String? // Make title optional
    var subtitle: String?
    var pirateIsland: PirateIsland?

    init(id: UUID, coordinate: CLLocationCoordinate2D, title: String?, pirateIsland: PirateIsland?) {
        self.id = id
        self.coordinate = coordinate
        self.title = title // Now title is optional
        self.subtitle = nil // You can set a subtitle if needed
        self.pirateIsland = pirateIsland
    }

    static func == (lhs: CustomMapMarker, rhs: CustomMapMarker) -> Bool {
        // Compare coordinate, title, and pirateIsland to determine equality
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.title == rhs.title &&
               lhs.pirateIsland == rhs.pirateIsland
    }
    
    static func forPirateIsland(_ island: PirateIsland) -> CustomMapMarker {
        CustomMapMarker(
            id: UUID(),
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
