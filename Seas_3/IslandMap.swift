//
//  IslandMap.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation
import MapKit


struct IslandMap: View {
    var islands: [CustomMapMarker]
    @Binding var region: MKCoordinateRegion

    init(islands: [CustomMapMarker], region: Binding<MKCoordinateRegion>) {
        self.islands = islands
        self._region = region
    }

    var body: some View {
        Map(position: .constant(.region(region))) {
            ForEach(islands) { marker in
                Annotation(marker.title ?? "Gym", coordinate: marker.coordinate) {
                    MapAnnotationContent()
                }
            }
        }
        .navigationTitle("Gym Map")
        .onAppear {
            print("Gym Map appeared with gyms count: \(islands.count)")
            for marker in islands {
                print("Gym: \(marker.title ?? "Unknown Gym"), Latitude: \(marker.coordinate.latitude), Longitude: \(marker.coordinate.longitude)")
            }
        }
    }
}

struct MapAnnotationContent: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .resizable()
            .frame(width: 30, height: 30)
            .foregroundColor(.red)
    }
}


struct IslandMap_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample binding region for preview
        let sampleRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        
        // Create a sample list of islands
        let sampleIslands: [CustomMapMarker] = [
            CustomMapMarker(id: UUID(), coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), title: "Sample Gym", pirateIsland: nil)
        ]

        return IslandMap(islands: sampleIslands, region: .constant(sampleRegion))
    }
}
