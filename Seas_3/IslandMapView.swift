//
//  IslandMapView.swift
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

struct IslandMapView: View {
    var islands: [PirateIsland]
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if islands.isEmpty {
                    Text("No islands available.")
                        .padding()
                } else {
                    ForEach(islands, id: \.self) { island in
                        VStack(alignment: .leading) {
                            Text("Gym: \(island.islandName)")
                            Text("Location: \(island.islandLocation)")

                            if island.latitude != 0 && island.longitude != 0 {
                                IslandMapViewMap(
                                    coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                                    islandName: island.islandName,
                                    islandLocation: island.islandLocation,
                                    onTap: {
                                        selectedIsland = island
                                        showModal = true
                                    }
                                )
                                .frame(height: 300)
                                .padding()

                                Button("Open in Maps") {
                                    openInMaps(island: island)
                                }
                                .padding(.top, 5)
                                .foregroundColor(.blue)
                            } else {
                                Text("Gym location not available")
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding()
            .navigationTitle("Gym Details")
            .sheet(isPresented: $showModal) {
                if let selectedIsland = selectedIsland {
                    let createdTimestamp = DateFormatter.localizedString(from: selectedIsland.createdTimestamp, dateStyle: .medium, timeStyle: .short)
                    let formattedTimestamp = DateFormatter.localizedString(from: selectedIsland.lastModifiedTimestamp ?? Date(), dateStyle: .medium, timeStyle: .short)

                    IslandModalView(
                        islandName: selectedIsland.islandName,
                        islandLocation: selectedIsland.islandLocation,
                        formattedCoordinates: "\(selectedIsland.latitude), \(selectedIsland.longitude)",
                        createdByUserId: selectedIsland.createdByUserId,
                        createdTimestamp: createdTimestamp,
                        lastModifiedByUserId: selectedIsland.lastModifiedByUserId,
                        formattedTimestamp: formattedTimestamp,
                        gymWebsite: selectedIsland.gymWebsite,
                        reviews: (selectedIsland.reviews?.array as? [Review]) ?? [],
                        averageStarRating: averageStarRating(for: (selectedIsland.reviews?.array as? [Review]) ?? [])
                    )
                } else {
                    Text("No Island Selected")
                        .padding()
                }
            }
        }
        .onAppear {
            print("Gym MapView appeared with gym count: \(islands.count)")
            for island in islands {
                print("Gym: \(island.islandName), Location: \(island.islandLocation), Latitude: \(island.latitude), Longitude: \(island.longitude)")
            }
        }
    }

    private func averageStarRating(for reviews: [Review]) -> String {
        guard !reviews.isEmpty else {
            return "No reviews"
        }

        let totalStars = reviews.reduce(0) { $0 + Int($1.stars) }
        let averageStars = Double(totalStars) / Double(reviews.count)
        return String(format: "%.1f", averageStars)
    }

    private func openInMaps(island: PirateIsland) {
        if island.latitude != 0 && island.longitude != 0 {
            let locationString = "\(island.latitude),\(island.longitude)"
            let nameAndLocation = "\(island.islandName), \(island.islandLocation)"
            let encodedLocation = locationString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedNameAndLocation = nameAndLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let finalUrlString = "http://maps.apple.com/?q=\(encodedNameAndLocation)&ll=\(encodedLocation)"
            if let url = URL(string: finalUrlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// Define CustomMarker conforming to Identifiable protocol
struct CustomMarker: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}

// Enhanced IslandModalView to display more information
struct IslandModalView: View {
    var islandName: String
    var islandLocation: String
    var formattedCoordinates: String
    var createdByUserId: String?
    var createdTimestamp: String
    var lastModifiedByUserId: String?
    var formattedTimestamp: String
    var gymWebsite: URL?
    var reviews: [Review]
    let averageStarRating: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Basic Information
            Text(islandName)
                .font(.system(size: 8))
                .bold()
            Text(islandLocation)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            
            // Coordinates
            HStack {
                Text("Coordinates:")
                    .font(.system(size: 8))
                Spacer()
                Text(formattedCoordinates)
                    .font(.system(size: 8))
            }

            // Website (if available)
            if let gymWebsite = gymWebsite {
                HStack {
                    Text("Website:")
                        .font(.system(size: 8))
                    Spacer()
                    Link(gymWebsite.absoluteString, destination: gymWebsite)
                        .font(.system(size: 8))
                        .foregroundColor(.blue)
                }
            }

            // Reviews (if available)
            if !reviews.isEmpty {
                HStack {
                    Text("Average Rating:")
                        .font(.system(size: 8))
                    Spacer()
                    Text(averageStarRating)
                        .font(.system(size: 8))
                }
            } else {
                Text("No reviews available.")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }

        }
        .padding()
    }
}

struct IslandMapView_Previews: PreviewProvider {
    static var previews: some View {
        IslandMapView(islands: [])
    }
}

struct IslandMapViewMap: View {
    var coordinate: CLLocationCoordinate2D
    var islandName: String
    var islandLocation: String
    var onTap: () -> Void // Closure to handle tap

    var body: some View {
        Map(
            coordinateRegion: .constant(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )),
            annotationItems: [CustomMarker(coordinate: coordinate)]
        ) { marker in
            MapAnnotation(coordinate: marker.coordinate) {
                VStack {
                    Text(islandName)
                        .font(.system(size: 8))
                        .foregroundColor(.black)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(5)
                        .padding(5)
                    Text(islandLocation)
                        .font(.footnote)
                        .foregroundColor(.black)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(5)
                        .padding(5)
                    Image(systemName: "mappin.circle.fill")
                        .resizable()
                        .foregroundColor(.red)
                        .frame(width: 30, height: 30)
                        .onTapGesture {
                            onTap() // Call onTap closure when tapped
                        }
                }
            }
        }
    }
}
