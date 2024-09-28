// AllIslandMapView.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit

// Equatable wrapper for MKCoordinateRegion
struct EquatableMKCoordinateRegion: Equatable {
    var region: MKCoordinateRegion

    static func == (lhs: EquatableMKCoordinateRegion, rhs: EquatableMKCoordinateRegion) -> Bool {
        lhs.region.center.latitude == rhs.region.center.latitude &&
        lhs.region.center.longitude == rhs.region.center.longitude &&
        lhs.region.span.latitudeDelta == rhs.region.span.latitudeDelta &&
        lhs.region.span.longitudeDelta == rhs.region.span.longitudeDelta
    }
}

// Extracted content view for the modal
struct IslandModalContentView: View {
    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedDay: DayOfWeek?
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?

    var body: some View {
        if let selectedIsland = selectedIsland {
            let reviewsArray = ReviewUtils.getReviews(from: selectedIsland.reviews)
            let averageRating = ReviewUtils.averageStarRating(for: reviewsArray)

            let dayOfWeekData = (selectedIsland.appDayOfWeeks?.allObjects as? [AppDayOfWeek])?
                .compactMap { $0.dayOfWeek } ?? []

            // Use the custom DateFormat utilities
            let createdTimestamp = DateFormat.mediumDateTime.string(from: selectedIsland.createdTimestamp)
            let formattedTimestamp = DateFormat.mediumDateTime.string(from: selectedIsland.lastModifiedTimestamp ?? Date())

            VStack {
                Text("Gym Name: \(selectedIsland.islandName ?? "Unknown")")
                IslandModalView(
                    customMapMarker: CustomMapMarker(
                        id: selectedIsland.islandID ?? UUID(),
                        coordinate: CLLocationCoordinate2D(latitude: selectedIsland.latitude, longitude: selectedIsland.longitude),
                        title: selectedIsland.islandName ?? "Unknown Gym",
                        pirateIsland: selectedIsland
                    ),
                    islandName: selectedIsland.islandName ?? "Unknown Gym",
                    islandLocation: selectedIsland.islandLocation ?? "Unknown Location",
                    formattedCoordinates: "\(selectedIsland.latitude), \(selectedIsland.longitude)",
                    createdTimestamp: createdTimestamp,
                    formattedTimestamp: formattedTimestamp,
                    gymWebsite: selectedIsland.gymWebsite,
                    reviews: ReviewUtils.getReviews(from: selectedIsland.reviews),
                    dayOfWeekData: dayOfWeekData,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: EnterZipCodeViewModel(
                        repository: AppDayOfWeekRepository.shared,
                        context: PersistenceController.preview.container.viewContext
                    )
                )
            }
            .frame(width: 300, height: 400)
            .background(Color.white)
            .cornerRadius(10)
            .padding()

        } else {
            EmptyView()
        }
    }
}

struct ConsolidatedIslandMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland>

    @StateObject private var viewModel: AppDayOfWeekViewModel
    @StateObject private var locationManager: UserLocationMapViewModel
    @State private var selectedRadius: Double = 5.0
    @State private var equatableRegion = EquatableMKCoordinateRegion(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var pirateMarkers: [CustomMapMarker] = []
    @State private var showModal = false
    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var fetchedLocation: CLLocation?

    init(viewModel: AppDayOfWeekViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _locationManager = StateObject(wrappedValue: UserLocationMapViewModel())
        _selectedDay = State(initialValue: .monday)
    }

    var body: some View {
        NavigationView {
            VStack {
                if locationManager.userLocation != nil {
                    makeMapView()
                    makeRadiusPicker()
                } else {
                    Text("Fetching user location...")
                        .navigationTitle("Gyms Near Me")
                }
            }
            .navigationTitle("Gyms Near Me")
            .overlay(overlayContentView())
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
                mapAnnotationView(for: marker)
            }
        }
        .frame(height: 300)
        .padding()
    }


    private func makeRadiusPicker() -> some View {
        RadiusPicker(selectedRadius: $selectedRadius)
            .padding()
    }


    private func overlayContentView() -> some View {
        ZStack {
            if showModal {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showModal = false
                    }
                
                if let selectedIsland = selectedIsland {
                    IslandModalView(
                        customMapMarker: CustomMapMarker(
                            id: selectedIsland.islandID ?? UUID(),
                            coordinate: CLLocationCoordinate2D(latitude: selectedIsland.latitude, longitude: selectedIsland.longitude),
                            title: selectedIsland.islandName ?? "Unknown Gym",
                            pirateIsland: selectedIsland
                        ),
                        islandName: selectedIsland.islandName ?? "Unknown Gym",
                        islandLocation: selectedIsland.islandLocation ?? "Unknown Location",
                        formattedCoordinates: "\(selectedIsland.latitude), \(selectedIsland.longitude)",
                        createdTimestamp: DateFormat.mediumDateTime.string(from: selectedIsland.createdTimestamp),
                        formattedTimestamp: DateFormat.mediumDateTime.string(from: selectedIsland.lastModifiedTimestamp ?? Date()),
                        gymWebsite: selectedIsland.gymWebsite,
                        reviews: ReviewUtils.getReviews(from: selectedIsland.reviews),
                        dayOfWeekData: (selectedIsland.appDayOfWeeks?.allObjects as? [AppDayOfWeek])?.compactMap { $0.dayOfWeek } ?? [],
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        selectedIsland: $selectedIsland,
                        viewModel: viewModel,
                        selectedDay: $selectedDay,
                        showModal: $showModal,
                        enterZipCodeViewModel: EnterZipCodeViewModel(
                            repository: AppDayOfWeekRepository.shared,
                            context: PersistenceController.preview.container.viewContext
                        )
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 10)
                    .padding()
                    .transition(.opacity)
                } else {
                    Text("No Gym Selected")
                        .padding()
                }
            }
        }
        .animation(.easeInOut, value: showModal)
    }

    private func mapAnnotationView(for marker: CustomMapMarker) -> some View {
        VStack {
            Text(marker.title ?? "")
                .font(.caption)
                .padding(5)
                .background(Color.white)
                .cornerRadius(5)
                .shadow(radius: 3)
            CustomMarkerView()
                .onTapGesture {
                    if let pirateIsland = marker.pirateIsland {
                        selectedIsland = pirateIsland
                        showModal = true
                    }
                }
        }
        .onAppear {
            print("Annotation view for marker: \(marker)")
        }
    }

    private func onAppear() {
        locationManager.startLocationServices()
        if let userLocation = locationManager.userLocation {
            updateRegion(userLocation, radius: selectedRadius)
        }
    }

    private func onChangeUserLocation(_ newUserLocation: CLLocation?) {
        guard let newUserLocation = newUserLocation else { return }
        updateRegion(newUserLocation, radius: selectedRadius)

        let address = "Your Address Here"
        let retryCount = 3

        MapUtils.fetchLocation(for: address, selectedRadius: selectedRadius, retryCount: retryCount) { location, error in
            if let error = error {
                print("Error fetching location: \(error)")
                return
            }

            if location != nil {
                // Handle the fetched location
            }
        }
    }


    private func onChangeEquatableRegion(_ newRegion: EquatableMKCoordinateRegion) {
        // Handle region change
    }

    private func onChangeSelectedRadius(_ newRadius: Double) {
        if let userLocation = locationManager.userLocation {
            updateRegion(userLocation, radius: newRadius)
        }
    }

    private func updateRegion(_ location: CLLocation, radius: Double) {
        let newRegion = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 1609.34,  // Convert miles to meters
            longitudinalMeters: radius * 1609.34
        )
        equatableRegion = EquatableMKCoordinateRegion(region: newRegion)
        updateMarkers(for: newRegion)
    }

    private func updateMarkers(for region: MKCoordinateRegion) {
        let radiusInMeters = region.span.latitudeDelta * 111_000  // Approximate meters per degree of latitude
        pirateMarkers = islands.filter { island in
            let islandLocation = CLLocation(latitude: island.latitude, longitude: island.longitude)
            let distance = islandLocation.distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude))
            return distance <= radiusInMeters
        }.map { island in
            CustomMapMarker(
                id: island.islandID ?? UUID(),
                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                title: island.islandName,
                pirateIsland: island
            )
        }
        print("Markers updated: \(pirateMarkers)")
    }


}


import SwiftUI
import CoreLocation
import MapKit

// Create a mock PirateIsland for the preview
struct MockData {
    static let sampleIsland: PirateIsland = {
        let context = PersistenceController.preview.container.viewContext
        let island = PirateIsland(context: context)
        island.islandID = UUID()
        island.islandName = "Sample Gym"
        island.islandLocation = "Sample Location"
        island.latitude = 37.7749
        island.longitude = -122.4194
        island.createdTimestamp = Date()
        island.lastModifiedTimestamp = Date()
        island.gymWebsite = URL(string: "https://www.sampleisland.com")
        return island
    }()

    static let sampleViewModel: AppDayOfWeekViewModel = {
        let repository = AppDayOfWeekRepository.shared
        let enterZipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: PersistenceController.preview.container.viewContext
        )
        return AppDayOfWeekViewModel(
            repository: repository,
            enterZipCodeViewModel: enterZipCodeViewModel
        )
    }()
}
struct ConsolidatedIslandMapView_Previews: PreviewProvider {
    static var previews: some View {
        let mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let locationManager = UserLocationMapViewModel()
        locationManager.userLocation = mockLocation

        return ConsolidatedIslandMapView(viewModel: MockData.sampleViewModel)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(locationManager)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Consolidated Island Map View")
            .previewDevice("iPhone 14 Pro")
    }
}
