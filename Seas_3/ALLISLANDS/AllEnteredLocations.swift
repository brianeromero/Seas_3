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
    
    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel

    init(context: NSManagedObjectContext) {
        let dataManager = PirateIslandDataManager(viewContext: context)
        _viewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(dataManager: dataManager))
        
        // Initialize EnterZipCodeViewModel here
        _enterZipCodeViewModel = StateObject(wrappedValue: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: context
        ))
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
                        viewModel.updateRegion()
                    }
                }
            }
            .navigationTitle("All Gyms Entered")
            .onAppear {
                viewModel.fetchPirateIslands()
            }
            .sheet(isPresented: $showModal) {
                if let island = selectedIsland {
                    IslandModalView(
                        customMapMarker: CustomMapMarker.forPirateIsland(island),
                        islandName: island.islandName ?? "Unknown", // Change this line
                        islandLocation: island.safeIslandLocation,
                        formattedCoordinates: island.formattedCoordinates,
                        createdTimestamp: island.formattedTimestamp,
                        formattedTimestamp: island.formattedTimestamp,
                        gymWebsite: island.gymWebsite,
                        reviews: ReviewUtils.getReviews(from: island.reviews),
                        averageStarRating: ReviewUtils.averageStarRating(for: ReviewUtils.getReviews(from: island.reviews)),
                        dayOfWeekData: island.daysOfWeekArray.compactMap { DayOfWeek(rawValue: $0.day ?? "") },
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        selectedIsland: $selectedIsland,
                        viewModel: AppDayOfWeekViewModel(
                            repository: AppDayOfWeekRepository.shared,
                            enterZipCodeViewModel: enterZipCodeViewModel
                        ),
                        selectedDay: $selectedDay,
                        showModal: $showModal,
                        enterZipCodeViewModel: enterZipCodeViewModel
                    )
                } else {
                    Text("No Island Selected")
                        .padding()
                }
            }
        }
    }

    func handleTap(location: CustomMapMarker) {
        print("Tapped on location: \(location.title ?? "Unknown Title")")

        if let pirateIsland = viewModel.getPirateIsland(from: location) {
            print("Fetched pirate island: \(pirateIsland.islandName ?? "Unknown Name")")

            self.selectedIsland = pirateIsland
            print("Updated selectedIsland: \(selectedIsland?.islandName ?? "Unknown Name")")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("Presenting modal")
                self.showModal = true
            }
        } else {
            print("No pirate island found")
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
