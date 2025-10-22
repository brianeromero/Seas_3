//
//  MapDetails.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/1/24.
//

import Foundation
import MapKit

struct MapDetails {
    static let startingLocation = CLLocationCoordinate2D(latitude: 33.783550, longitude: -118.035652)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
}
