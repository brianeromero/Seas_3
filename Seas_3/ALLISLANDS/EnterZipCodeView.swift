//
//  EnterZipCodeView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreLocation
import MapKit
import CoreData

struct EnterZipCodeView: View {
    @ObservedObject var viewModel: EnterZipCodeViewModel
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel

    @State private var locationInput: String = ""
    @State private var searchResults: [PirateIsland] = []
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedIsland: PirateIsland? = nil
    @State private var showModal: Bool = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek? = nil
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var selectedRadius: Double = 5.0 // Radius in miles

    var body: some View {
        VStack {
            TextField("Enter Location (Zip Code, Address, City, State)", text: $locationInput)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Use the reusable RadiusPicker component
            RadiusPicker(selectedRadius: $selectedRadius)

            Button(action: search) {
                Text("Search")
            }
            .padding()

            // Map View
            IslandMapView(
                viewModel: appDayOfWeekViewModel, // Corrected to AppDayOfWeekViewModel
                selectedIsland: $selectedIsland,
                showModal: $showModal,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                selectedDay: $selectedDay, // Added this line
                allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                enterZipCodeViewModel: viewModel // Corrected to EnterZipCodeViewModel
            )
            .frame(height: 400)
            .onChange(of: searchResults) { _ in
                if let firstIsland = searchResults.first {
                    self.region.center = CLLocationCoordinate2D(latitude: firstIsland.latitude, longitude: firstIsland.longitude)
                }
            }
        }
        .padding()
        .sheet(isPresented: $showModal) {
            if let island = selectedIsland {
                IslandModalView(
                    customMapMarker: CustomMapMarker(
                        id: UUID(),
                        coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                        title: island.name ?? "", // Use a default value if name is nil
                        pirateIsland: island // Unwrapped here
                    ),
                    islandName: island.name ?? "", // Default to empty string if nil
                    islandLocation: island.islandLocation ?? "", // Default to empty string if nil
                    formattedCoordinates: island.formattedCoordinates,
                    createdTimestamp: DateFormat.full.string(from: island.createdTimestamp),
                    formattedTimestamp: DateFormat.full.string(from: island.lastModifiedTimestamp ?? Date()),
                    gymWebsite: island.gymWebsite,
                    reviews: island.reviews?.compactMap { $0 as? Review } ?? [],
                    averageStarRating: ReviewUtils.averageStarRating(for: island.reviews?.compactMap { $0 as? Review } ?? []),
                    dayOfWeekData: island.daysOfWeekArray.compactMap { DayOfWeek(rawValue: $0.day ?? "") },
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: appDayOfWeekViewModel, // Corrected to AppDayOfWeekViewModel
                    selectedDay: $selectedDay, // Corrected to Binding<DayOfWeek?>
                    showModal: $showModal, // Corrected order
                    enterZipCodeViewModel: viewModel // Corrected to EnterZipCodeViewModel
                )
            } else {
                Text("No Island Selected")
                    .padding()
            }
        }
    }

    private func search() {
        MapUtils.fetchLocation(for: locationInput, selectedRadius: selectedRadius) { coordinate, error in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }

            guard let coordinate = coordinate else {
                print("No location found for the input.")
                return
            }

            // Update the region with the new coordinates
            self.region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))

            // Fetch Pirate Islands near the found location
            self.viewModel.fetchPirateIslandsNear(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                within: selectedRadius * 1609.34 // Convert miles to meters
            )

            // Safely unwrap optional PirateIsland
            self.searchResults = self.viewModel.pirateIslands.compactMap { $0.pirateIsland }
        }
    }

}

struct EnterZipCodeView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock context and repository
        let context = PersistenceController.preview.container.viewContext
        let mockRepository = AppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        let mockIsland = PirateIsland(context: context)
        
        
        // Create mock PirateIsland (Gym) objects
        let newYorkIsland = PirateIsland(context: context)
        newYorkIsland.latitude = 40.7128
        newYorkIsland.longitude = -74.0060
        newYorkIsland.islandName = "NY Gym"
        newYorkIsland.islandID = UUID()

        let eugeneIsland = PirateIsland(context: context)
        eugeneIsland.latitude = 44.0521
        eugeneIsland.longitude = -123.0868
        eugeneIsland.islandName = "Eugene Gym"
        eugeneIsland.islandID = UUID()
        
        do {
            try context.save()
        } catch {
            print("Failed to save mock data: \(error.localizedDescription)")
        }

        // Create mock view models
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(
            repository: mockRepository,
            context: context
        )
        
        let mockAppDayOfWeekViewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland, // Pass the mock PirateIsland instance
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        
        let mockAllEnteredLocationsViewModel = AllEnteredLocationsViewModel(
            dataManager: PirateIslandDataManager(viewContext: context)
        )
        
        return EnterZipCodeView(
            viewModel: mockEnterZipCodeViewModel,
            appDayOfWeekViewModel: mockAppDayOfWeekViewModel,
            allEnteredLocationsViewModel: mockAllEnteredLocationsViewModel
        )
        .environment(\.managedObjectContext, context)
    }
}
