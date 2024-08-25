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

// Extracted modal content view
struct IslandModalContentView: View {
    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool

    var body: some View {
        Group {
            if let selectedIsland = selectedIsland {
                let reviewsArray = getReviews(from: selectedIsland.reviews)
                let averageRating = averageStarRating(for: reviewsArray)
                VStack {
                    IslandModalView(
                        islandName: selectedIsland.islandName,
                        islandLocation: selectedIsland.islandLocation,
                        formattedCoordinates: "\(selectedIsland.latitude), \(selectedIsland.longitude)",
                        createdByUserId: selectedIsland.createdByUserId,
                        createdTimestamp: DateFormatter.localizedString(from: selectedIsland.createdTimestamp, dateStyle: .short, timeStyle: .short),
                        lastModifiedByUserId: selectedIsland.lastModifiedByUserId,
                        formattedTimestamp: DateFormatter.localizedString(from: selectedIsland.lastModifiedTimestamp ?? Date(), dateStyle: .short, timeStyle: .short),
                        gymWebsite: selectedIsland.gymWebsite,
                        reviews: reviewsArray,
                        averageStarRating: averageRating
                    )
                    .font(.system(size: 5)) // Apply font to the entire IslandModalView
                    .frame(width: 200, height: 150)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding()
                    
                    Button(action: {
                        showModal = false
                    }) {
                        Text("Close")
                            .font(.system(size: 8))
                            .padding(5)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    private func getReviews(from reviews: NSOrderedSet?) -> [Review] {
        guard let reviews = reviews else { return [] }
        return reviews.compactMap { $0 as? Review }.sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
    }

    private func averageStarRating(for reviews: [Review]) -> String {
        guard !reviews.isEmpty else {
            return "No reviews"
        }

        let totalStars = reviews.reduce(0) { $0 + Int($1.stars) }
        let averageStars = Double(totalStars) / Double(reviews.count)
        return String(format: "%.1f", averageStars)
    }
}

struct ConsolidatedIslandMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland>

    @ObservedObject private var locationManager: UserLocationMapViewModel
    @State private var selectedRadius: Double = 5.0
    @State private var equatableRegion: EquatableMKCoordinateRegion = EquatableMKCoordinateRegion(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var pirateMarkers: [CustomMapMarker] = []
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    
    
    init() {
        self.locationManager = UserLocationMapViewModel()
    }

    var body: some View {
        let mapView = makeMapView()
        let radiusPicker = makeRadiusPicker()

        return NavigationView {
            VStack {
                if locationManager.userLocation != nil {
                    mapView
                    radiusPicker
                } else {
                    Text("Fetching user location...")
                        .navigationTitle("Locations Near Me")
                }
            }
            .navigationTitle("Locations Near Me")
            .overlay(
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .opacity(0.5)
                    IslandModalContentView(selectedIsland: $selectedIsland, showModal: $showModal)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding()
                }
                .opacity(showModal ? 1 : 0)
            )
            .onAppear(perform: onAppear)
            .onChange(of: locationManager.userLocation, perform: onChangeUserLocation)
            .onChange(of: equatableRegion, perform: onChangeEquatableRegion)
            .onChange(of: selectedRadius, perform: onChangeSelectedRadius)
        }
    }

    private func makeMapView() -> some View {
        Map(coordinateRegion: Binding(
            get: { equatableRegion.region },
            set: { equatableRegion.region = $0 }
        ), showsUserLocation: true, annotationItems: pirateMarkers) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                VStack {
                    Text(marker.title)
                        .font(.caption)
                        .padding(5)
                        .background(Color.white)
                        .cornerRadius(5)
                        .shadow(radius: 3)
                    Image(systemName: marker.title == "You are Here" ? "figure.wrestling" : "mappin.circle.fill")
                        .foregroundColor(marker.title == "You are Here" ? .red : .blue)
                        .onTapGesture {
                            if let island = islands.first(where: { $0.islandName == marker.title }) {
                                selectedIsland = island
                                showModal = true
                            }
                        }
                }
            }
        }
        .frame(height: 300)
        .padding()
    }

    private func makeRadiusPicker() -> some View {
        RadiusPicker(selectedRadius: $selectedRadius)
            .padding()
    }

    private func onAppear() {
        locationManager.startLocationServices()
    }

    private func onChangeUserLocation(_ newUserLocation: CLLocation?) {
        if let newUserLocation = newUserLocation {
            updateRegion(newUserLocation, radius: selectedRadius)
            fetchPirateIslandsNear(newUserLocation, within: selectedRadius * 1609.34)
            addCurrentLocationMarker(newUserLocation)
        }
    }

    private func onChangeEquatableRegion(_ newRegion: EquatableMKCoordinateRegion) {
        updateMarkersForRegion(newRegion.region)
    }

    private func onChangeSelectedRadius(_ newRadius: Double) {
        if let userLocation = locationManager.userLocation {
            updateRegion(userLocation, radius: newRadius)
            fetchPirateIslandsNear(userLocation, within: newRadius * 1609.34)
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
        previewIsland.islandName = "Sample Gym"
        previewIsland.latitude = 37.7749
        previewIsland.longitude = -122.4194

        return ConsolidatedIslandMapView()
            .environment(\.managedObjectContext, context)
    }
}


