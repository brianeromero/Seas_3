//
//  AllEnteredLocations.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct AllEnteredLocations: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>
    
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var pirateMarkers: [CustomMapMarker] = []

    var body: some View {
        NavigationView {
            VStack {
                if !pirateMarkers.isEmpty {
                    Map(coordinateRegion: $region, annotationItems: pirateMarkers) { location in
                        MapAnnotation(coordinate: location.coordinate) {
                            VStack {
                                Text(location.title)
                                    .font(.caption)
                                    .padding(5)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .shadow(radius: 3)
                                CustomMarkerView()
                            }
                        }
                    }
                    .onAppear {
                        updateRegion()
                    }
                    .onChange(of: pirateMarkers) { _ in
                        updateRegion()
                    }
                } else {
                    Text("No Open Mats found.")
                        .padding()
                }
            }
            .navigationTitle("All Open Mats Map")
            .onAppear {
                logFetch()
                fetchPirateIslands()
            }
        }
    }

    private func fetchPirateIslands() {
        do {
            let results = try viewContext.fetch(PirateIsland.fetchRequest())
            print("Fetched \(results.count) PirateIsland objects.")
            
            let markers = results.compactMap { island -> CustomMapMarker? in
                if let title = island.islandName {
                    return CustomMapMarker(coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude), title: title)
                }
                return nil
            }
            
            DispatchQueue.main.async {
                self.pirateMarkers = markers
            }
        } catch {
            print("Failed to fetch PirateIsland: \(error)")
        }
    }

    private func updateRegion() {
        guard !pirateMarkers.isEmpty else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            return
        }

        let coordinates = pirateMarkers.map { $0.coordinate }
        let mapRect = coordinates.map { MKMapPoint($0) }
                                 .reduce(MKMapRect.null) { $0.union(MKMapRect(origin: $1, size: MKMapRect.null.size)) }
        
        region = MKCoordinateRegion(mapRect)
    }
    
    private func logFetch() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            let results = try viewContext.fetch(fetchRequest)
            print("Fetched \(results.count) PirateIsland objects.")
        } catch {
            print("Failed to fetch PirateIsland: \(error)")
        }
    }
}

struct AllEnteredLocations_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared

        return AllEnteredLocations()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
