//
//  IslandMap.swift
//  Mat_Finder
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
