// AllIslandMapView.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct RadiusPicker: View {
    @Binding var selectedRadius: Double

    var body: some View {
        VStack {
            Text("Select Radius: \(String(format: "%.1f", selectedRadius)) miles")
            Slider(value: $selectedRadius, in: 1...50, step: 1)
                .padding(.horizontal)
        }
    }
}

struct EquatableMKCoordinateRegion: Equatable {
    var region: MKCoordinateRegion

    static func == (lhs: EquatableMKCoordinateRegion, rhs: EquatableMKCoordinateRegion) -> Bool {
        return lhs.region.center.latitude == rhs.region.center.latitude &&
               lhs.region.center.longitude == rhs.region.center.longitude &&
               lhs.region.span.latitudeDelta == rhs.region.span.latitudeDelta &&
               lhs.region.span.longitudeDelta == rhs.region.span.longitudeDelta
    }
}

// Extracted modal content view
struct IslandModalContentView: View {
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedIsland: PirateIsland?
    @Binding var showModal: Bool
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedDay: DayOfWeek? // Make this optional

    init(selectedIsland: Binding<PirateIsland?>, showModal: Binding<Bool>, viewModel: AppDayOfWeekViewModel, selectedDay: Binding<DayOfWeek?>) {
        _selectedIsland = selectedIsland
        _showModal = showModal
        self.viewModel = viewModel
        _selectedDay = selectedDay
    }

    var body: some View {
        if let selectedIsland = selectedIsland {
            let reviewsArray = ReviewUtils.getReviews(from: selectedIsland.reviews)
            let averageRating = ReviewUtils.averageStarRating(for: reviewsArray)

            let dayOfWeekData: [DayOfWeek] = (selectedIsland.appDayOfWeeks?.allObjects as? [AppDayOfWeek])?
                .compactMap { $0.dayOfWeek } ?? []

            VStack {
                IslandModalView(
                    islandName: selectedIsland.islandName ?? "Unknown Island",
                    islandLocation: selectedIsland.islandLocation ?? "Unknown Location",
                    formattedCoordinates: "\(selectedIsland.latitude), \(selectedIsland.longitude)",
                    createdTimestamp: DateFormatter.localizedString(from: selectedIsland.createdTimestamp, dateStyle: .short, timeStyle: .short),
                    formattedTimestamp: DateFormatter.localizedString(from: selectedIsland.lastModifiedTimestamp ?? Date(), dateStyle: .short, timeStyle: .short),
                    gymWebsite: selectedIsland.gymWebsite,
                    reviews: reviewsArray,
                    averageStarRating: averageRating,
                    dayOfWeekData: dayOfWeekData,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay, // Now this matches the optional type
                    showModal: $showModal,
                    width: .constant(300),
                    height: .constant(400)
                )
                .frame(width: 300, height: 400)
                .background(Color.white)
                .cornerRadius(10)
                .padding()

                Button(action: {
                    showModal = false
                }) {
                    Text("Close")
                        .font(.system(size: 8, design: .default))
                        .padding(5)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
            }
        } else {
            EmptyView()
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
    @State private var equatableRegion: EquatableMKCoordinateRegion = EquatableMKCoordinateRegion(
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

    init(viewModel: AppDayOfWeekViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _locationManager = StateObject(wrappedValue: UserLocationMapViewModel())
    }

    var body: some View {
        NavigationView {
            VStack {
                if locationManager.userLocation != nil {
                    makeMapView()
                    makeRadiusPicker()
                } else {
                    Text("Fetching user location...")
                        .navigationTitle("Locations Near Me")
                }
            }
            .navigationTitle("Locations Near Me")
            .overlay(
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .opacity(0.5)
                    IslandModalContentView(
                        selectedIsland: $selectedIsland,
                        showModal: $showModal,
                        viewModel: viewModel,
                        selectedDay: $selectedDay
                    )
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding()
                }
                .opacity(showModal ? 1 : 0)
            )
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
                VStack {
                    Text(marker.title)
                        .font(.caption)
                        .padding(5)
                        .background(Color.white)
                        .cornerRadius(5)
                        .shadow(radius: 3)
                    Image(systemName: marker.title == "You are Here" ? "figure.wrestling" : "mappin.circle.fill")
                        .foregroundColor(marker.title == "You are Here" ? .red : .blue)
                        .onTapGesture {
                            if let island = islands.first(where: { $0.islandName == marker.title }) {
                                selectedIsland = island
                                showModal = true
                            }
                        }
                }
            }
        }
        .frame(height: 300)
        .padding()
    }

    private func makeRadiusPicker() -> some View {
        RadiusPicker(selectedRadius: $selectedRadius)
            .padding()
    }

    private func onAppear() {
        locationManager.startLocationServices()
    }

    private func onChangeUserLocation(_ newUserLocation: CLLocation?) {
        guard let newUserLocation = newUserLocation else {
            return
        }
        updateRegion(newUserLocation, radius: selectedRadius)
        fetchPirateIslandsNear(newUserLocation, within: selectedRadius * 1609.34)
        addCurrentLocationMarker(newUserLocation)
    }

    private func onChangeEquatableRegion(_ newRegion: EquatableMKCoordinateRegion) {
        updateMarkersForRegion(newRegion.region)
    }

    private func onChangeSelectedRadius(_ newRadius: Double) {
        if let userLocation = locationManager.userLocation {
            updateRegion(userLocation, radius: newRadius)
            fetchPirateIslandsNear(userLocation, within: newRadius * 1609.34)
        }
    }

    private func fetchPirateIslandsNear(_ location: CLLocation, within distance: CLLocationDistance) {
        // Implement your logic to fetch pirate islands near a location
        // For now, mock implementation with preview data
        pirateMarkers = islands.map { island in
            CustomMapMarker(
                id: island.islandID ?? UUID(), // Default to a new UUID if islandID is nil
                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                title: island.islandName ?? "Unnamed Island" // Default to "Unnamed Island" if islandName is nil
            )
        }
    }

    private func updateRegion(_ userLocation: CLLocation, radius: Double) {
        let span = MKCoordinateSpan(latitudeDelta: radius / 69.0, longitudeDelta: radius / 69.0)
        equatableRegion.region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
    }

    private func addCurrentLocationMarker(_ userLocation: CLLocation) {
        let currentLocationMarker = CustomMapMarker(
            id: UUID(), // Generate a unique ID for the current location marker
            coordinate: userLocation.coordinate,
            title: "You are Here"
        )
        pirateMarkers.append(currentLocationMarker)
    }

    private func updateMarkersForRegion(_ region: MKCoordinateRegion) {
        // Implement your logic to update markers based on the visible region
        // For now, mock implementation with preview data
        pirateMarkers = islands.map { island in
            CustomMapMarker(
                id: island.islandID ?? UUID(), // Default to a new UUID if islandID is nil
                coordinate: CLLocationCoordinate2D(latitude: island.latitude, longitude: island.longitude),
                title: island.islandName ?? "Unnamed Island" // Default to "Unnamed Island" if islandName is nil
            )
        }
    }
}

struct ConsolidatedIslandMapView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a preview persistence controller and context
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        // Create a repository using the preview persistence controller
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)

        // Initialize the viewModel with the required parameters
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: repository
        )

        // Pass the viewModel and the managed object context to the preview view
        ConsolidatedIslandMapView(viewModel: viewModel)
            .environment(\.managedObjectContext, context)
    }
}
