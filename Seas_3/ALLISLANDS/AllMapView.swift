//
//  AllMapView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

struct CoordinateWrapper: Equatable {
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: CoordinateWrapper, rhs: CoordinateWrapper) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct AllMapView: View {
    @State private var region: MKCoordinateRegion
    let islands: [PirateIsland]
    let userLocation: CoordinateWrapper

    init(islands: [PirateIsland], userLocation: CLLocationCoordinate2D) {
        self.islands = islands
        self.userLocation = CoordinateWrapper(coordinate: userLocation)
        
        let initialRegion = MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        self._region = State(initialValue: initialRegion)
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: islands.compactMap { island -> CustomMapMarker? in
            // Use optional coalescing to provide default values for optional properties
            let title = island.islandName ?? "Unnamed Gym"
            let latitude = island.latitude
            let longitude = island.longitude
            
            // Use ReviewUtils to get the reviews for the island, with added caller function logging
            let reviews = ReviewUtils.getReviews(from: island.reviews, callerFunction: #function)
            
            // Example: Printing reviews for debugging
            print("Reviews for \(title): \(reviews)")

            // Create a CustomMapMarker for each island
            return CustomMapMarker(
                id: island.islandID ?? UUID(), // Use default UUID if islandID is nil
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                title: title,
                pirateIsland: island
            )
        }) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                VStack {
                    Text(marker.title ?? "Unnamed Gym")
                        .font(.caption)
                        .padding(5)
                        .background(Color.white)
                        .cornerRadius(5)
                    CustomMarkerView() // Use your custom marker view here
                }
            }
        }
        .frame(height: 300) // Adjust as needed
        .padding()
        .onAppear {
            updateRegion()
            print("Map appeared with region: \(region)")
        }
        .onChange(of: CoordinateWrapper(coordinate: region.center)) { newCenter in
            print("Region center changed to: \(newCenter.coordinate.latitude), \(newCenter.coordinate.longitude)")
        }
    }

    private func updateRegion() {
        let radius: Double = 5.0 // Replace with your desired radius
        region = MapUtils.updateRegion(markers: [CustomMapMarker(id: UUID(), coordinate: userLocation.coordinate, title: "", pirateIsland: nil)], selectedRadius: radius, center: userLocation.coordinate)
        print("Updated region to: \(region.center.latitude), \(region.center.longitude)")
    }
}
