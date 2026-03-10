// DayOfWeekSearchView.swift
// Mat_Finder
//
// Created by Brian Romero on 8/21/24.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData
import Combine



struct DayOfWeekSearchView: View {
    @Binding var navigationPath: NavigationPath   // <- pass this in

    @State private var selectedIsland: PirateIsland?
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    @ObservedObject private var userLocationMapViewModel = UserLocationMapViewModel.shared
    @EnvironmentObject var viewModel: AppDayOfWeekViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @State private var radius: Double = 10.0
    @State private var errorMessage: String?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal: Bool = false
    
    @State private var showIslandList = false

    var body: some View {
        GeometryReader { geo in
            VStack {
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { _, _ in
                        Task { await updateIslandsAndRegion() }
                    }

                ErrorView(errorMessage: $errorMessage)

                ZStack {

                    IslandMKMapView(
                        islands: viewModel.islandsWithMatTimes.map(\.0),
                        selectedIsland: $selectedIsland,
                        showModal: $showModal,
                        selectedRadius: 5.0,
                        region: region
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack {
                        Spacer()

                        HStack {
                            Spacer()

                            VStack(spacing: 12) {

                                // 🌍 Fit All Results
                                Button {

                                    guard let mapView = IslandMKMapView.sharedMapView else { return }

                                    let region = regionToFitResults()

                                    mapView.setRegion(region, animated: true)

                                    mapView.setVisibleMapRect(
                                        mapView.visibleMapRect,
                                        edgePadding: UIEdgeInsets(top: 120, left: 80, bottom: 120, right: 80),
                                        animated: true
                                    )

                                } label: {

                                    Image(systemName: "globe.americas.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.blue)
                                        .padding(12)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                                }

                                // 📍 Recenter
                                RecenterMapButton(userLocationVM: userLocationMapViewModel)

                                // ☰ List
                                Button {
                                    showIslandList = true
                                } label: {

                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.blue)
                                        .padding(12)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                                }
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 90)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .floatingModal(isPresented: $showModal) {
                IslandModalContainer(
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    showModal: $showModal,
                    enterZipCodeViewModel: enterZipCodeViewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    navigationPath: $navigationPath // <- pass binding from parent
                )
            }
            .onAppear(perform: handleOnAppear)
            .onChange(of: userLocationMapViewModel.userLocation) { _, newValue in
                guard let location = newValue else { return }

                if selectedIsland == nil {
                    updateRegion(center: location.coordinate)
                }

                if viewModel.islandsWithMatTimes.isEmpty {
                    Task { await updateIslandsAndRegion() }
                }
            }
            .onChange(of: selectedIsland) { _, newValue in
                updateSelectedIsland(from: newValue)
            }
            
            .onChange(of: showModal) { _, isShown in
                if !isShown {
                    selectedIsland = nil
                }
            }
            
            
            .sheet(isPresented: $showIslandList) {

                DayOfWeekIslandListView(
                    islands: viewModel.islandsWithMatTimes.map(\.0),
                    userLocation: userLocationMapViewModel.userLocation
                ) { island in

                    selectedIsland = island
                    zoomToIsland(island)
                    showModal = true
                    showIslandList = false
                }
            }
        }
    }
    
    private func regionToFitResults() -> MKCoordinateRegion {

        let islands = viewModel.islandsWithMatTimes.map(\.0)

        let coordinates = islands.map {
            CLLocationCoordinate2D(
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }

        guard !coordinates.isEmpty else { return region }

        guard
            let minLat = coordinates.map({ $0.latitude }).min(),
            let maxLat = coordinates.map({ $0.latitude }).max(),
            let minLon = coordinates.map({ $0.longitude }).min(),
            let maxLon = coordinates.map({ $0.longitude }).max()
        else { return region }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: min(max((maxLat - minLat) * 1.5, 0.05), 180),
            longitudeDelta: min(max((maxLon - minLon) * 1.5, 0.05), 180)
        )

        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func zoomToIsland(_ island: PirateIsland) {

        guard let mapView = IslandMKMapView.sharedMapView else { return }

        let coordinate = CLLocationCoordinate2D(
            latitude: island.latitude,
            longitude: island.longitude
        )

        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 8000,
            longitudinalMeters: 8000
        )

        mapView.setRegion(region, animated: true)
    }


    // MARK: - Event Handlers

    private func handleOnAppear() {
        if let location = userLocationMapViewModel.userLocation {
            updateRegion(center: location.coordinate)
            Task { await updateIslandsAndRegion() }
        } else {
            userLocationMapViewModel.requestLocation()
        }
    }


    // MARK: - Data Updates

    private func updateIslandsAndRegion() async {

        guard let selectedDay else {
            errorMessage = "Day of week is not selected."
            return
        }

        await viewModel.fetchIslands(forDay: selectedDay)

        let islands = viewModel.islandsWithMatTimes.map(\.0)

        if islands.count > 50 {
            showIslandList = true
        }

        if selectedIsland == nil,
           let location = userLocationMapViewModel.userLocation {
            updateRegion(center: location.coordinate)
        }
    }

    private func updateSelectedIsland(from newIsland: PirateIsland?) {
        guard let newIsland else { return }

        if let matchingIsland = viewModel.islandsWithMatTimes
            .map(\.0)
            .first(where: { $0.islandID == newIsland.islandID }) {
            selectedIsland = matchingIsland
        } else {
            errorMessage = "Island not found in the current selection."
        }
    }

    private func updateRegion(center: CLLocationCoordinate2D) {

        let islands = viewModel.islandsWithMatTimes.map(\.0)

        guard !islands.isEmpty else { return }

        let latitudes = islands.map { $0.latitude }
        let longitudes = islands.map { $0.longitude }

        let minLat = latitudes.min() ?? center.latitude
        let maxLat = latitudes.max() ?? center.latitude

        let minLon = longitudes.min() ?? center.longitude
        let maxLon = longitudes.max() ?? center.longitude

        let span = MKCoordinateSpan(
            latitudeDelta: max(maxLat - minLat, 0.05),
            longitudeDelta: max(maxLon - minLon, 0.05)
        )

        withAnimation {
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

enum DistanceFilter: Double, CaseIterable, Identifiable {

    case ten = 10
    case twentyFive = 25
    case fifty = 50
    case unlimited = 9999

    var id: Double { rawValue }

    var title: String {

        switch self {
        case .ten: return "10 miles"
        case .twentyFive: return "25 miles"
        case .fifty: return "50 miles"
        case .unlimited: return "All"
        }
    }
}

struct DayOfWeekIslandListView: View {

    let islands: [PirateIsland]
    let userLocation: CLLocation?

    let onSelect: (PirateIsland) -> Void

    @State private var filter: DistanceFilter = .twentyFive

    private func distance(for island: PirateIsland) -> Double? {

        guard
            let userLocation,
            island.latitude != 0,
            island.longitude != 0
        else { return nil }

        let islandLocation = CLLocation(
            latitude: island.latitude,
            longitude: island.longitude
        )

        return userLocation.distance(from: islandLocation) / 1609.34
    }

    private var filteredIslands: [PirateIsland] {

        islands.filter {

            guard let miles = distance(for: $0) else { return true }

            return miles <= filter.rawValue
        }
    }

    private var sortedIslands: [PirateIsland] {

        filteredIslands.sorted {

            let d1 = distance(for: $0) ?? .greatestFiniteMagnitude
            let d2 = distance(for: $1) ?? .greatestFiniteMagnitude

            return d1 < d2
        }
    }

    var body: some View {

        NavigationStack {

            VStack {

                // Distance Filter
                Picker("Distance", selection: $filter) {

                    ForEach(DistanceFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }

                }
                .pickerStyle(.segmented)
                .padding()

                List {

                    ForEach(sortedIslands, id: \.objectID) { island in

                        Button {

                            onSelect(island)

                        } label: {

                            HStack {

                                VStack(alignment: .leading, spacing: 4) {

                                    Text(island.islandName ?? "Unknown Gym")
                                        .font(.headline)

                                    Text(island.islandLocation ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let miles = distance(for: island) {

                                        Text(String(format: "%.1f miles away", miles))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }

            .navigationTitle("Locations (\(sortedIslands.count))")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    @Binding var errorMessage: String?

    var body: some View {
        if let errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
        }
    }
}
