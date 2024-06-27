//
//  AllMapView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import MapKit

// Custom Equatable conformance for CLLocationCoordinate2D
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct AllMapView: View {
    @State private var region: MKCoordinateRegion
    let islands: [PirateIsland]
    let userLocation: CLLocationCoordinate2D

    init(islands: [PirateIsland], userLocation: CLLocationCoordinate2D) {
        self.islands = islands
        self.userLocation = userLocation
        
        let initialRegion = MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        self._region = State(initialValue: initialRegion)
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: islands.compactMap { island -> CustomMapMarker? in
            guard let title = island.islandName else { return nil }
            let latitude = island.latitude
            let longitude = island.longitude
            
            return CustomMapMarker(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), title: title)
        }) { location in
            MapAnnotation(coordinate: location.coordinate) {
                VStack {
                    Text(location.title)
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

        .frame(height: 300)
        .padding()
        .onAppear {
            updateRegion()
            print("Map appeared with region: \(region)")
        }
        .onChange(of: region.center) { newCenter in
            print("Region center changed to: \(newCenter.latitude), \(newCenter.longitude)")
        }
    }
    
    private func updateRegion() {
        region = MKCoordinateRegion(
            center: userLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        print("Updated region to: \(region.center.latitude), \(region.center.longitude)")
    }
}
