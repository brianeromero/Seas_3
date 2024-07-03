// AllIslandMapView.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//
import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct RadiusPicker: View {
    @Binding var selectedRadius: Double
    
    var body: some View {
        VStack {
            Text("Select Radius: \(String(format: "%.1f", selectedRadius)) miles")
            Slider(value: $selectedRadius, in: 1...50, step: 1)
                .padding(.horizontal)
        }
    }
}

struct EquatableMKCoordinateRegion: Equatable {
    var region: MKCoordinateRegion
    
    static func == (lhs: EquatableMKCoordinateRegion, rhs: EquatableMKCoordinateRegion) -> Bool {
        return lhs.region.center.latitude == rhs.region.center.latitude &&
               lhs.region.center.longitude == rhs.region.center.longitude &&
               lhs.region.span.latitudeDelta == rhs.region.span.latitudeDelta &&
               lhs.region.span.longitudeDelta == rhs.region.span.longitudeDelta
    }
}

struct ConsolidatedIslandMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    @ObservedObject private var locationManager = UserLocationMapViewModel() // Use real UserLocationMapViewModel
    @State private var selectedRadius: Double = 5.0
    @State private var equatableRegion: EquatableMKCoordinateRegion = EquatableMKCoordinateRegion(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var pirateMarkers: [CustomMapMarker] = []

    var body: some View {
        NavigationView {
            VStack {
                if locationManager.userLocation != nil {
                    Map(coordinateRegion: Binding(
                        get: { equatableRegion.region },
                        set: { equatableRegion.region = $0 }
                    ), showsUserLocation: true, annotationItems: pirateMarkers) { location in
                        MapAnnotation(coordinate: location.coordinate) {
                            VStack {
                                Text(location.title)
                                    .font(.caption)
                                    .padding(5)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .shadow(radius: 3)
                                Image(systemName: location.title == "You are Here" ? "figure.wrestling" : "mappin.circle.fill")
                                    .foregroundColor(location.title == "You are Here" ? .red : .blue)
                            }
                        }
                    }
                    .frame(height: 300)
                    .padding()

                    RadiusPicker(selectedRadius: $selectedRadius)
                        .padding()

                } else {
                    Text("Fetching user location...")
                        .navigationTitle("Locations Near Me")
                }
            }
            .navigationTitle("Locations Near Me")
            .onAppear {
                locationManager.startLocationServices()
            }
            .onChange(of: locationManager.userLocation) { newUserLocation in
                if let newUserLocation = newUserLocation {
                    updateRegion(newUserLocation, radius: selectedRadius)
                    fetchPirateIslandsNear(newUserLocation, within: selectedRadius * 1609.34)
                    addCurrentLocationMarker(newUserLocation)
                }
            }
            .onChange(of: equatableRegion) { newRegion in
                updateMarkersForRegion(newRegion.region)
            }
            .onChange(of: selectedRadius) { newRadius in
                if let userLocation = locationManager.userLocation {
                    updateRegion(userLocation, radius: newRadius)
                    fetchPirateIslandsNear(userLocation, within: newRadius * 1609.34)
                }
            }
        }
    }

    private func fetchPirateIslandsNear(_ location: CLLocation, within distance: CLLocationDistance) {
        // Implement your logic to fetch pirate islands near a location
        // For now, mock implementation with preview data
        pirateMarkers = islands.map { island in
            CustomMapMarker(id: island.islandID ?? UUID(), coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude), title: island.islandName)
        }
    }

    private func updateRegion(_ userLocation: CLLocation, radius: Double) {
        let span = MKCoordinateSpan(latitudeDelta: radius / 69.0, longitudeDelta: radius / 69.0)
        equatableRegion.region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
    }

    private func addCurrentLocationMarker(_ userLocation: CLLocation) {
        let currentLocationMarker = CustomMapMarker(id: UUID(), coordinate: userLocation.coordinate, title: "You are Here")
        pirateMarkers.append(currentLocationMarker)
    }

    private func updateMarkersForRegion(_ newRegion: MKCoordinateRegion) {
        // Clear existing markers
        pirateMarkers.removeAll()

        // Fetch new markers based on the current region
        let center = CLLocation(latitude: newRegion.center.latitude, longitude: newRegion.center.longitude)
        fetchPirateIslandsNear(center, within: selectedRadius * 1609.34)

        // Add current location marker if available
        if let userLocation = locationManager.userLocation {
            addCurrentLocationMarker(userLocation)
        }
    }
}

struct ConsolidatedIslandMapView_Previews: PreviewProvider {
    static var previews: some View {
        // Ensure the preview works with a valid managed object context and mock data
        let context = PersistenceController.preview.container.viewContext
        let previewIsland = PirateIsland(context: context)
        previewIsland.islandName = "Sample Island"
        previewIsland.latitude = 37.7749
        previewIsland.longitude = -122.4194

        return ConsolidatedIslandMapView()
            .environment(\.managedObjectContext, context)
    }
}
