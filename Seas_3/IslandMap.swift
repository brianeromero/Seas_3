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
    let islands: [PirateIsland]
    @State private var region: MKCoordinateRegion

    init(islands: [PirateIsland]) {
        self.islands = islands

        var centerCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        var minLat: Double?
        var maxLat: Double?
        var minLon: Double?
        var maxLon: Double?

        for island in islands {
            guard island.latitude != 0.0 && island.longitude != 0.0 else {
                continue
            }
            
            if minLat == nil || maxLat == nil || minLon == nil || maxLon == nil {
                minLat = island.latitude
                maxLat = island.latitude
                minLon = island.longitude
                maxLon = island.longitude
            } else {
                minLat = min(minLat!, island.latitude)
                maxLat = max(maxLat!, island.latitude)
                minLon = min(minLon!, island.longitude)
                maxLon = max(maxLon!, island.longitude)
            }
        }

        if let minLat = minLat, let maxLat = maxLat, let minLon = minLon, let maxLon = maxLon {
            centerCoordinate = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        }

        let span = MKCoordinateSpan(latitudeDelta: (maxLat ?? 0) - (minLat ?? 0), longitudeDelta: (maxLon ?? 0) - (minLon ?? 0))
        _region = State(initialValue: MKCoordinateRegion(center: centerCoordinate, span: span))
    }

    var body: some View {
        Map(coordinateRegion: $region, interactionModes: [], showsUserLocation: false, userTrackingMode: nil, annotationItems: islands.compactMap { island -> MapAnnotationItem? in
            guard island.latitude != 0.0 && island.longitude != 0.0 else {
                return nil
            }
            return MapAnnotationItem(coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude))
        }) { item in
            item.mapAnnotation() // Use mapAnnotation method to create MapAnnotation
        }
        .navigationTitle("Gym Map")
        .onAppear {
            print("Gym Map appeared with gyms count: \(islands.count)")
            for island in islands {
                print("Gym: \(String(describing: island.islandName)), Location: \(String(describing: island.islandLocation)), Latitude: \(island.latitude), Longitude: \(island.longitude)")
            }
        }
    }
}

// Define MapAnnotationItem conforming to MapAnnotationProtocol
struct MapAnnotationItem: Identifiable {
    var id = UUID() // Provide a default ID
    var coordinate: CLLocationCoordinate2D

    // Implement mapAnnotation method to conform to MapAnnotationProtocol
    func mapAnnotation() -> MapAnnotation<MapAnnotationContent> {
        MapAnnotation(coordinate: coordinate) {
            MapAnnotationContent()
        }
    }
}

// Define MapAnnotationContent as a View conforming to View protocol
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
        IslandMap(islands: [])
    }
}
