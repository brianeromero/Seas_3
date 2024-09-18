// DayOfWeekSearchView.swift
// Seas_3
//
// Created by Brian Romero on 8/21/24.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData
import Combine

struct DayOfWeekSearchView: View {
    @Binding var selectedIsland: PirateIsland?
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var region: MKCoordinateRegion
    @Binding var searchResults: [PirateIsland]

    @StateObject private var userLocationMapViewModel = UserLocationMapViewModel()
    @StateObject private var viewModel = AppDayOfWeekViewModel(
        repository: AppDayOfWeekRepository.shared,
        enterZipCodeViewModel: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: PersistenceController.shared.container.viewContext
        )
    )

    @State private var radius: Double = 10.0
    @State private var equatableRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var errorMessage: String?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal: Bool = false

    @StateObject private var enterZipCodeViewModel = EnterZipCodeViewModel(
        repository: AppDayOfWeekRepository.shared,
        context: PersistenceController.shared.container.viewContext
    )

    var body: some View {
        NavigationView {
            VStack {
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { _ in
                        Task { await dayOfWeekChanged() }
                    }

                RadiusPicker(selectedRadius: $radius)
                    .onChange(of: radius) { _ in
                        Task { await radiusChanged() }
                    }

                ErrorView(errorMessage: $errorMessage)

                MapViewContainer(equatableRegion: $equatableRegion, appDayOfWeekViewModel: viewModel) { island in
                    handleIslandTap(island: island)
                }
            }
            .sheet(isPresented: $showModal) {
                IslandModalContainer(
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek
                )
            }
            .onAppear {
                setupInitialRegion()
                requestUserLocation()
            }
            .onChange(of: userLocationMapViewModel.userLocation) { newLocation in
                if let location = newLocation {
                    updateRegion(center: location.coordinate)
                    Task { await updateIslandsAndRegion() }
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                updateSelectedIsland(from: newIsland)
            }
        }
    }

    // Helper methods
    private func setupInitialRegion() {
        equatableRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }

    private func requestUserLocation() {
        userLocationMapViewModel.requestLocation()
    }

    private func dayOfWeekChanged() async {
        await updateIslandsAndRegion()
    }

    private func radiusChanged() async {
        await updateIslandsAndRegion()
    }

    private func updateSelectedIsland(from newIsland: PirateIsland?) {
        guard let newIsland = newIsland else { return }
        if let matchingIsland = viewModel.islandsWithMatTimes.map({ $0.0 }).first(where: { $0.islandID == newIsland.islandID }) {
            selectedIsland = matchingIsland
        }
    }
    
    // ErrorView.swift
    struct ErrorView: View {
        @Binding var errorMessage: String?

        var body: some View {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else {
                EmptyView()
            }
        }
    }
    
    // IslandModalContainer.swift
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
                    islandLocation: "\(selectedIsland.latitude), \(selectedIsland.longitude)",
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
    
    // MapViewContainer.swift (updated)
    struct MapViewContainer: View {
        @Binding var equatableRegion: MKCoordinateRegion
        @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel
        let handleIslandTap: (PirateIsland) -> Void

        var body: some View {
            Map(
                coordinateRegion: $equatableRegion,
                annotationItems: appDayOfWeekViewModel.islandsWithMatTimes.map { $0.0 }
            ) { island in
                MapAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude)
                ) {
                    IslandAnnotationView(island: island, handleIslandTap: { handleIslandTap(island) })
                }
            }
        }
    }
    
    private func updateRegion(center: CLLocationCoordinate2D) {
        if userLocationMapViewModel.userLocation != nil {
            withAnimation {
                equatableRegion = MapUtils.updateRegion(
                    markers: viewModel.islandsWithMatTimes.map {
                        CustomMapMarker(
                            id: $0.0.islandID ?? UUID(),
                            coordinate: CLLocationCoordinate2D(latitude: $0.0.latitude, longitude: $0.0.longitude),
                            title: $0.0.islandName ?? "Unnamed Island",
                            pirateIsland: $0.0
                        )
                    },
                    selectedRadius: radius,
                    center: center
                )
            }
        } else {
            errorMessage = "Error updating region: User location is nil"
        }
    }

    private func handleIslandTap(island: PirateIsland) {
        selectedIsland = island
        showModal = true
    }

    private func updateIslandsAndRegion() async {
        guard let selectedDay = selectedDay else {
            errorMessage = "Day of week is not selected."
            return
        }

        await viewModel.fetchIslands(forDay: selectedDay)
        if let location = userLocationMapViewModel.userLocation {
            updateRegion(center: location.coordinate)
        }
    }
}

// IslandAnnotationView.swift
struct IslandAnnotationView: View {
    let island: PirateIsland
    let handleIslandTap: () -> Void

    var body: some View {
        Button(action: handleIslandTap) {
            VStack {
                Text(island.islandName ?? "Unnamed Island")
                    .font(.caption)
                    .padding(5)
                    .background(Color.white)
                    .cornerRadius(5)
                    .shadow(radius: 3)
                CustomMarkerView()
            }
        }
    }
}

struct DayOfWeekSearchView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let viewContext = persistenceController.container.viewContext
        
        createSampleData(viewContext: viewContext)

        return VStack {
            DayOfWeekSearchView(
                selectedIsland: .constant(PirateIsland(context: viewContext)),
                selectedAppDayOfWeek: .constant(AppDayOfWeek(context: viewContext)),
                region: .constant(MKCoordinateRegion()),
                searchResults: .constant([PirateIsland(context: viewContext)])
            )
            .environment(\.managedObjectContext, viewContext)
            .previewDisplayName("Default Preview")

            DayOfWeekSearchView(
                selectedIsland: .constant(nil),
                selectedAppDayOfWeek: .constant(nil),
                region: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))),
                searchResults: .constant([])
            )
            .environment(\.managedObjectContext, viewContext)
            .previewDisplayName("Los Angeles Region")

            DayOfWeekSearchView(
                selectedIsland: .constant(PirateIsland(context: viewContext)),
                selectedAppDayOfWeek: .constant(AppDayOfWeek(context: viewContext)),
                region: .constant(MKCoordinateRegion()),
                searchResults: .constant([PirateIsland(context: viewContext)])
            )
            .environment(\.managedObjectContext, viewContext)
            .previewDisplayName("Selected Island and Day")

            DayOfWeekSearchView(
                selectedIsland: .constant(nil),
                selectedAppDayOfWeek: .constant(nil),
                region: .constant(MKCoordinateRegion()),
                searchResults: .constant([PirateIsland(context: viewContext)])
            )
            .environment(\.managedObjectContext, viewContext)
            .previewDisplayName("Search with no selections")
        }
    }

    static func createSampleData(viewContext: NSManagedObjectContext) {
        for i in 1..<5 {
            let pirateIsland = PirateIsland(context: viewContext)
            pirateIsland.islandID = UUID()
            pirateIsland.islandName = "Island \(i)"
            pirateIsland.latitude = 34.0522
            pirateIsland.longitude = -118.2437
        }
        try? viewContext.save()
    }
}
