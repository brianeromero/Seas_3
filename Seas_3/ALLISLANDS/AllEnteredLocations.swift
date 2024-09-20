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
    @StateObject private var appDayOfWeekViewModel: AppDayOfWeekViewModel

    init(context: NSManagedObjectContext) {
        let dataManager = PirateIslandDataManager(viewContext: context)
        _viewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(dataManager: dataManager))
        
        let enterZipCodeViewModel = StateObject(wrappedValue: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: context
        ))
        
        _enterZipCodeViewModel = enterZipCodeViewModel
        _appDayOfWeekViewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: enterZipCodeViewModel.wrappedValue
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
                    let pirateIslands: [PirateIsland] = viewModel.pirateMarkers.compactMap { location in
                        return viewModel.getPirateIsland(from: location)
                    }
                    
                    Map(coordinateRegion: $viewModel.region, annotationItems: pirateIslands) { island in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude)) {
                            IslandAnnotationView(island: island, handleIslandTap: {
                                handleIslandTap(island: island)
                            })
                        }
                    }
                    .onAppear {
                        viewModel.logTileInformation()
                        viewModel.updateRegion()
                    }
                }
            }
            .navigationTitle("All Gyms")
            .onAppear {
                viewModel.fetchPirateIslands()
            }
            .sheet(isPresented: $showModal) {
                IslandModalContainer(
                    selectedIsland: $selectedIsland,
                    viewModel: appDayOfWeekViewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek
                )
            }
        }
    }

    private func handleIslandTap(island: PirateIsland) {
        selectedIsland = island
        showModal = true
    }
    
    struct IslandModalContainer: View {
        @Binding var selectedIsland: PirateIsland?
        @ObservedObject var viewModel: AppDayOfWeekViewModel
        @Binding var selectedDay: DayOfWeek?
        @Binding var showModal: Bool
        @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
        @Binding var selectedAppDayOfWeek: AppDayOfWeek?

        var body: some View {
            if let selectedIsland = selectedIsland {
                IslandModalView(
                    customMapMarker: nil,
                    islandName: selectedIsland.islandName ?? "",
                    islandLocation: selectedIsland.islandLocation ?? "",
                    formattedCoordinates: selectedIsland.formattedCoordinates,
                    createdTimestamp: selectedIsland.createdTimestamp.description,
                    formattedTimestamp: selectedIsland.formattedTimestamp,
                    gymWebsite: selectedIsland.gymWebsite,
                    reviews: selectedIsland.reviews?.array as? [Review] ?? [],
                    averageStarRating: "",
                    dayOfWeekData: [],
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel
                )
            } else {
                EmptyView()
            }
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
