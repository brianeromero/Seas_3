//
// AllEnteredLocations.swift
// Seas2
//
// Created by Brian Romero on 6/17/24.
import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct AllEnteredLocations: View {
    @State private var selectedDay: DayOfWeek? = .monday
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: AllEnteredLocationsViewModel
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    init(context: NSManagedObjectContext) {
        let dataManager = PirateIslandDataManager(viewContext: context)
        _viewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(dataManager: dataManager))
    }

    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.pirateMarkers.isEmpty {
                    Text("No Open Mats found.")
                        .padding()
                } else {
                    Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.pirateMarkers) { location in
                        MapAnnotation(coordinate: location.coordinate) {
                            VStack {
                                Text(location.title ?? "Unknown Title")
                                    .font(.caption)
                                    .padding(5)
                                    .background(Color.white)
                                    .cornerRadius(5)
                                    .shadow(radius: 3)
                                CustomMarkerView()
                            }
                            .onTapGesture {
                                handleTap(location: location)
                            }
                        }
                    }
                    .onAppear {
                        viewModel.logTileInformation()
                    }
                }
            }
            .navigationTitle("All Open Mats Map")
            .onAppear {
                viewModel.fetchPirateIslands()
            }
            .sheet(isPresented: $showModal) {
                if let island = selectedIsland {
                    let name = island.name ?? ""
                    let location = island.islandLocation ?? ""
                    let coordinates = island.formattedCoordinates
                    let created = DateFormat.full.string(from: island.createdTimestamp)
                    let modified = DateFormat.full.string(from: island.lastModifiedTimestamp ?? Date())
                    let website = island.gymWebsite
                    let reviews = island.reviews?.compactMap { $0 as? Review } ?? []
                    let avgRating = ReviewUtils.averageStarRating(for: reviews)
                    let days = island.daysOfWeekArray.compactMap { DayOfWeek(rawValue: $0.day ?? "") }

                    IslandModalView(
                        customMapMarker: CustomMapMarker(
                            id: UUID(),
                            coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                            title: name,
                            pirateIsland: island
                        ),
                        width: .constant(300),
                        height: .constant(500),
                        islandName: name,
                        islandLocation: location,
                        formattedCoordinates: coordinates,
                        createdTimestamp: created,
                        formattedTimestamp: modified,
                        gymWebsite: website,
                        reviews: reviews,
                        averageStarRating: avgRating,
                        dayOfWeekData: days,
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        selectedIsland: $selectedIsland,
                        viewModel: AppDayOfWeekViewModel(repository: AppDayOfWeekRepository.shared),
                        selectedDay: $selectedDay,
                        showModal: $showModal
                    )
                } else {
                    Text("No Island Selected")
                        .padding()
                }
            }

        }
    }

    func handleTap(location: CustomMapMarker) {
        if let pirateIsland = viewModel.getPirateIsland(from: location) {
            self.selectedIsland = pirateIsland
            self.showModal = true
        }
    }
}

struct AllEnteredLocations_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.viewContext

        return AllEnteredLocations(context: context)
            .environment(\.managedObjectContext, context)
            .previewDisplayName("All Entered Locations Preview")
    }
}
