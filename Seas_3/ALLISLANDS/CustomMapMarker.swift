//
//  CustomMapMarker.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import CoreLocation

struct CustomMapMarker: Identifiable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String
}

extension CustomMapMarker {
    static func == (lhs: CustomMapMarker, rhs: CustomMapMarker) -> Bool {
        // Compare coordinate and title to determine equality
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.title == rhs.title
    }
}
