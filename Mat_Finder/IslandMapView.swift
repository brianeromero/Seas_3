// IslandMapView.swift
// Mat_Finder
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation
import MapKit

struct IslandMapView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedDay: DayOfWeek?
    @ObservedObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Binding var region: MKCoordinateRegion
    @Binding var searchResults: [PirateIsland]
    
    @State private var navigationPath = NavigationPath()


    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: searchResults) { island in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude)) {
                    VStack {
                        Text(island.islandName ?? "Unknown Title")
                            .font(.caption)
                            .padding(5)
                            // --- THIS IS THE KEY CHANGE ---
                            .background(Color(.systemBackground)) // Adapts to light/dark mode
                            .cornerRadius(5)
                            .foregroundColor(.primary) // Ensure text is adaptive
                        CustomMarkerView()
                    }
                    .onTapGesture {
                        handleTap(island: island)
                    }
                }
            }
            .frame(height: 400)
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showModal) {
            if let island = selectedIsland {
                IslandModalView(
                    customMapMarker: CustomMapMarker.forPirateIsland(island),
                    islandName: island.islandName ?? "Unknown",
                    islandLocation: island.islandLocation ?? "Unknown",
                    formattedCoordinates: island.formattedCoordinates,
                    createdTimestamp: island.formattedTimestamp,
                    formattedTimestamp: island.formattedTimestamp,
                    gymWebsite: island.gymWebsite,
                    dayOfWeekData: island.daysOfWeekArray.compactMap { DayOfWeek(rawValue: $0.day) },
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: self.enterZipCodeViewModel,
                    navigationPath: $navigationPath // <-- Add this
                )
            } else {
                Text("No Gym Selected")
                    .padding()
                    .foregroundColor(.primary)
            }
        }
    }

    func handleTap(island: PirateIsland) {
        self.selectedIsland = island
        self.showModal = true
    }

}


struct IslandMapContent: View {
    var islands: [PirateIsland]
    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedDay: DayOfWeek? // Changed to optional
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    var enterZipCodeViewModel: EnterZipCodeViewModel

    var body: some View {
        VStack(alignment: .leading) {
            if islands.isEmpty {
                Text("No Gyms available.")
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
                            .frame(height: 400)
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


struct CustomMarker: Identifiable {
    let id = UUID()
    var coordinate: CLLocationCoordinate2D
}

struct IslandMapViewMap: View {
    var coordinate: CLLocationCoordinate2D
    var islandName: String
    var islandLocation: String
    var onTap: (PirateIsland) -> Void
    var island: PirateIsland

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
                        .font(.caption)
                        .padding(5)
                        // --- THIS IS THE KEY CHANGE ---
                        .background(Color(.systemBackground)) // Adapts to light/dark mode
                        .cornerRadius(5)
                        .foregroundColor(.primary) // Ensure text is adaptive
                    CustomMarkerView()
                }
                .onTapGesture {
                    onTap(island)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .alert(isPresented: $showConfirmationDialog) {
            Alert(
                title: Text("Open in Maps?").foregroundColor(.primary), // Ensure alert title text is adaptive
                message: Text("Do you want to open \(islandName) in Maps?").foregroundColor(.primary), // Ensure alert message text is adaptive
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

/*
struct IslandMapView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        let island1 = PirateIsland(context: persistenceController.container.viewContext)
        island1.islandName = "Gym 1"
        island1.islandLocation = "123 Main St"
        island1.latitude = 37.7749
        island1.longitude = -122.4194
        island1.createdTipmestamp = Date()
        island1.gymWebsite = URL(string: "https://gym1.com")
        
        let island2 = PirateIsland(context: persistenceController.container.viewContext)
        island2.islandName = "Gym 2"
        island2.islandLocation = "456 Elm St"
        island2.latitude = 37.7859
        island2.longitude = -122.4364
        island2.createdTimestamp = Date()
        island2.gymWebsite = URL(string: "https://gym2.com")
        
        let dataManager = PirateIslandDataManager(viewContext: persistenceController.container.viewContext)
        let allEnteredLocationsViewModel = AllEnteredLocationsViewModel(dataManager: dataManager)
        let enterZipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: persistenceController
        )
        let appDayOfWeekViewModel = AppDayOfWeekViewModel(
            selectedIsland: island1,
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: enterZipCodeViewModel
        )
        
        return Group {
            IslandMapView(
                viewModel: appDayOfWeekViewModel,
                selectedIsland: .constant(island1),
                showModal: .constant(false),
                selectedAppDayOfWeek: .constant(nil),
                selectedDay: .constant(nil),
                allEnteredLocationsViewModel: allEnteredLocationsViewModel,
                enterZipCodeViewModel: enterZipCodeViewModel,
                region: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )),
                searchResults: .constant([island1, island2])
            )
            .previewDisplayName("Gym Map View")
            
            IslandMapViewMap(
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                islandName: "Gym 1",
                islandLocation: "123 Main St",
                onTap: { _ in },
                island: island1
            )
            .previewDisplayName("Gym Map View Map")
            
            CustomMarkerView()
                .previewLayout(.sizeThatFits)
                .padding()
                .background(Color.white)
                .previewDisplayName("Custom Marker View")
        }
    }
}
*/
