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
            let title = island.islandName ?? "Unnamed Island"
            let latitude = island.latitude
            let longitude = island.longitude
            
            // Use ReviewUtils to get the reviews for the island
            let reviews = ReviewUtils.getReviews(from: island.reviews)
            
            // Example: Printing reviews for debugging
            print("Reviews for \(title): \(reviews)")

            // Create a CustomMapMarker for each island
            return CustomMapMarker(id: island.islandID ?? UUID(), coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: title)
        }) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                VStack {
                    Text(marker.title)
                        .font(.caption)
                        .padding(5)
                        .background(Color.white)
                        .cornerRadius(5)
                        .shadow(radius: 3)
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
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
        region = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        print("Updated region to: \(region.center.latitude), \(region.center.longitude)")
    }
}
