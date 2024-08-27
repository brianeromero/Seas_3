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
                                onTap: {
                                    selectedIsland = island
                                    showModal = true
                                }
                            )
                            .frame(height: 300)
                            .padding()
                        } else {
                            Text("Gym location not available")
                        }
                    }
                    .padding()
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

    @State private var viewModel = AppDayOfWeekViewModel(
        PersistenceController.shared,
        selectedIsland: nil,
        repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared)
    )
    
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
                )
            )
            .padding()
            .navigationTitle("Gym Details")
            .sheet(isPresented: $showModal) {
                if let island = selectedIsland {
                    IslandModalView(
                        islandName: island.islandName ?? "Unknown Name",
                        islandLocation: island.islandLocation ?? "Unknown Location",
                        formattedCoordinates: island.formattedCoordinates,
                        createdTimestamp: island.createdTimestamp.description,
                        formattedTimestamp: island.formattedTimestamp.description,
                        gymWebsite: island.gymWebsite,
                        reviews: Array(island.reviews ?? []) as? [Review] ?? [],
                        averageStarRating: ReviewUtils.averageStarRating(for: Array(island.reviews ?? []) as? [Review] ?? []),
                        dayOfWeekData: [],
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        selectedIsland: $selectedIsland,
                        viewModel: viewModel,
                        selectedDay: $selectedDay
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

struct IslandModalView: View {
    let islandName: String
    let islandLocation: String
    let formattedCoordinates: String
    let createdTimestamp: String
    let formattedTimestamp: String
    let gymWebsite: URL?
    let reviews: [Review]
    let averageStarRating: String
    let dayOfWeekData: [DayOfWeek]
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedDay: DayOfWeek?
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?

    init(
        islandName: String,
        islandLocation: String,
        formattedCoordinates: String,
        createdTimestamp: String,
        formattedTimestamp: String,
        gymWebsite: URL?,
        reviews: [Review],
        averageStarRating: String,
        dayOfWeekData: [DayOfWeek],
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel,
        selectedDay: Binding<DayOfWeek?>
    ) {
        self.islandName = islandName
        self.islandLocation = islandLocation
        self.formattedCoordinates = formattedCoordinates
        self.createdTimestamp = createdTimestamp
        self.formattedTimestamp = formattedTimestamp
        self.gymWebsite = gymWebsite
        self.reviews = reviews
        self.averageStarRating = averageStarRating
        self.dayOfWeekData = dayOfWeekData
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
        self._selectedDay = selectedDay
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Basic Information
                Text(islandName)
                    .font(.system(size: 14)) // Increased font size
                    .bold()
                Text(islandLocation)
                    .font(.system(size: 12)) // Slightly increased font size
                    .foregroundColor(.secondary)

                // Coordinates
                HStack {
                    Text("Coordinates:")
                        .font(.system(size: 12))
                    Spacer()
                    Text(formattedCoordinates)
                        .font(.system(size: 12))
                }

                // Website (if available)
                if let gymWebsite = gymWebsite {
                    HStack {
                        Text("Website:")
                            .font(.system(size: 12))
                        Spacer()
                        Link("Visit Website", destination: gymWebsite)
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                } else {
                    Text("No website available.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Schedule NavigationLink
                Group {
                    if selectedAppDayOfWeek != nil {
                        NavigationLink(
                            destination: ScheduleFormView(
                                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                                selectedIsland: $selectedIsland,
                                viewModel: viewModel
                            )
                        ) {
                            Text("View Schedule")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                                .padding(.top, 10)
                        }
                    } else {
                        Text("No schedule available for this day.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                // Scheduled Mat Times Section
                ScheduledMatTimesSection(
                    matTimesForDay: $viewModel.matTimesForDay,
                    selectedDay: $selectedDay
                )
                
                // Reviews (if available)
                if !reviews.isEmpty {
                    HStack {
                        Text("Average Rating:")
                            .font(.system(size: 12))
                        Spacer()
                        Text(averageStarRating)
                            .font(.system(size: 12))
                    }
                } else {
                    Text("No reviews available.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}


struct IslandMapViewMap: View {
    var coordinate: CLLocationCoordinate2D
    var islandName: String
    var islandLocation: String
    var onTap: () -> Void

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
                    showConfirmationDialog = true
                    onTap() // Call the onTap action here
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
        
        return IslandMapView(
            islands: [island1, island2]
        )
    }
}
