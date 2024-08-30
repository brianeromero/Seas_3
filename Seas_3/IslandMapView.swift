// IslandMapView.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation
import MapKit

struct IslandMapContent: View {
    var islands: [PirateIsland]
    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedDay: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel // Updated

    var body: some View {
        VStack(alignment: .leading) {
            if islands.isEmpty {
                Text("No islands available.")
                    .padding()
            } else {
                ForEach(islands, id: \.islandID) { island in
                    VStack(alignment: .leading) {
                        Text("Gym: \(island.islandName ?? "Unknown Name")")
                        Text("Location: \(island.islandLocation ?? "Unknown Location")")

                        if island.latitude != 0 && island.longitude != 0 {
                            IslandMapViewMap(
                                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                                islandName: island.islandName ?? "Unknown Name",
                                islandLocation: island.islandLocation ?? "Unknown Location",
                                onTap: { tappedIsland in
                                    self.selectedIsland = tappedIsland
                                },
                                island: island
                            )
                            .frame(height: 300)
                            .padding()
                        } else {
                            Text("Gym location not available")
                        }
                    }
                    .padding()
                }

                if let selectedIsland = selectedIsland {
                    NavigationLink(
                        destination: ViewScheduleForIsland(
                            viewModel: viewModel,
                            island: selectedIsland
                        )
                    ) {
                        Text("View Schedule")
                    }
                }
            }
        }
    }
}

struct IslandMapView: View {
    var islands: [PirateIsland]
    @State private var selectedIsland: PirateIsland?
    @State private var showConfirmationDialog = false
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @ObservedObject var viewModel: AppDayOfWeekViewModel // Updated
    
    var body: some View {
        NavigationView {
            IslandMapContent(
                islands: islands,
                selectedIsland: $selectedIsland,
                showModal: $showModal,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                selectedDay: Binding<DayOfWeek>(
                    get: { self.selectedDay ?? .monday },
                    set: { self.selectedDay = $0 }
                ),
                viewModel: viewModel // Add this line
            )
            .padding()
            .navigationTitle("Gym Details")
            .sheet(isPresented: $showModal) {
                if let island = selectedIsland {
                    let reviews = Array(island.reviews ?? []) as? [Review] ?? []
                    let averageRating = ReviewUtils.averageStarRating(for: reviews)
                    IslandModalView(
                        islandName: island.islandName ?? "Unknown Name",
                        islandLocation: island.islandLocation ?? "Unknown Location",
                        formattedCoordinates: island.formattedCoordinates,
                        createdTimestamp: island.createdTimestamp.description,
                        formattedTimestamp: island.formattedTimestamp.description,
                        gymWebsite: island.gymWebsite,
                        reviews: reviews,
                        averageStarRating: averageRating,
                        dayOfWeekData: [],
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        selectedIsland: $selectedIsland,
                        viewModel: viewModel,
                        selectedDay: $selectedDay,
                        showModal: $showModal,
                        width: .constant(UIScreen.main.bounds.width * 0.8),
                        height: .constant(UIScreen.main.bounds.height * 0.7)
                    )
                } else {
                    Text("No Island Selected")
                        .padding()
                }
            }
            .onAppear {
                print("Gym MapView appeared with gym count: \(islands.count)")
            }
        }
    }
}
                
                
struct CustomMarker: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}

struct IslandMapViewMap: View {
    var coordinate: CLLocationCoordinate2D
    var islandName: String
    var islandLocation: String
    var onTap: (PirateIsland) -> Void
    var island: PirateIsland // Add this property


    @State private var showConfirmationDialog = false

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
                        .font(.system(size: 10))
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
                }
                .onTapGesture {
                    onTap(island) // Pass the island object to the onTap action
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .alert(isPresented: $showConfirmationDialog) {
            Alert(
                title: Text("Open in Maps?"),
                message: Text("Do you want to open \(islandName) in Maps?"),
                primaryButton: .default(Text("Open")) {
                    ReviewUtils.openInMaps(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        islandName: islandName,
                        islandLocation: islandLocation
                    )
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct IslandMapView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a Core Data preview context
        let context = PersistenceController.preview.container.viewContext
        
        // Create sample PirateIsland entities
        let island1 = PirateIsland(context: context)
        island1.islandName = "Gym 1"
        island1.islandLocation = "123 Main St"
        island1.latitude = 37.7749
        island1.longitude = -122.4194
        island1.createdTimestamp = Date()
        island1.gymWebsite = URL(string: "https://gym1.com")
        
        let island2 = PirateIsland(context: context)
        island2.islandName = "Gym 2"
        island2.islandLocation = "456 Elm St"
        island2.latitude = 37.7859
        island2.longitude = -122.4364
        island2.createdTimestamp = Date()
        island2.gymWebsite = URL(string: "https://gym2.com")
        
        // Create a sample AppDayOfWeekViewModel instance
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: AppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        )
        
        return IslandMapView(
            islands: [island1, island2],
            viewModel: viewModel // Pass the viewModel instance
        )
    }
}
