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


struct IslandWithTimes: Identifiable {
    let island: PirateIsland
    let times: [MatTime]

    var id: NSManagedObjectID {
        island.objectID
    }
}

struct DayOfWeekSearchView: View {
    @Binding var navigationPath: NavigationPath
    
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
    
    // ✅ KEEP ONLY THIS ONE
    @State private var selectedDay: DayOfWeek? = .monday
    
    @State private var showModal: Bool = false
    @State private var showIslandList = false
    
    private var islands: [PirateIsland] {
        viewModel.islandsWithMatTimes.map(\.0)
    }
    
    var body: some View {
        VStack {

            // ✅ Day picker
            DayPickerView(selectedDay: $selectedDay)
                .padding()
                .onChange(of: selectedDay) { _, _ in
                    Task { await updateIslandsAndRegion() }
                }

            ErrorView(errorMessage: $errorMessage)

            ZStack {

                IslandMKMapView(
                    islands: islands,
                    selectedIsland: $selectedIsland,
                    showModal: $showModal,
                    selectedRadius: radius,
                    region: region
                )

                MapControlsView(
                    fitAction: {
                        guard let mapView = IslandMKMapView.sharedMapView else { return }

                        let region = regionToFitResults()

                        mapView.setRegion(region, animated: true)

                        mapView.setVisibleMapRect(
                            mapView.visibleMapRect,
                            edgePadding: UIEdgeInsets(
                                top: 120,
                                left: 80,
                                bottom: 120,
                                right: 80
                            ),
                            animated: true
                        )
                    },

                    listAction: {
                        showIslandList = true
                    },

                    userLocationVM: userLocationMapViewModel
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .floatingModal(isPresented: $showModal) {
            IslandModalContainer(
                selectedIsland: $selectedIsland,
                viewModel: viewModel,
                selectedDay: $selectedDay,
                showModal: $showModal,
                enterZipCodeViewModel: enterZipCodeViewModel,
                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                navigationPath: $navigationPath
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
                islandsWithMatTimes: viewModel.islandsWithMatTimes,
                userLocation: userLocationMapViewModel.userLocation,
                selectedDay: $selectedDay   // ✅ binding
            ) { island in
                
                selectedIsland = island
                zoomToIsland(island)
                showModal = true
                showIslandList = false
            }
        }
    }
    
    // MARK: - Helpers
    
    private func regionToFitResults() -> MKCoordinateRegion {

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
    
    // MARK: - Lifecycle
    
    private func handleOnAppear() {
        if let location = userLocationMapViewModel.userLocation {
            updateRegion(center: location.coordinate)
            Task { await updateIslandsAndRegion() }
        } else {
            userLocationMapViewModel.requestLocation()
        }
    }
    
    // MARK: - Data
    
    private func updateIslandsAndRegion() async {

        guard let selectedDay else {
            errorMessage = "Day of week is not selected."
            return
        }

        await viewModel.fetchIslands(forDay: selectedDay)

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

        if let matchingIsland = islands.first(where: { $0.islandID == newIsland.islandID }) {
            selectedIsland = matchingIsland
        } else {
            errorMessage = "Island not found in the current selection."
        }
    }
    
    private func updateRegion(center: CLLocationCoordinate2D) {

        guard !islands.isEmpty else {
            withAnimation {
                region.center = center
            }
            return
        }

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

    let islandsWithMatTimes: [(PirateIsland, [MatTime])]
    let userLocation: CLLocation?
    @Binding var selectedDay: DayOfWeek?
    
    let onSelect: (PirateIsland) -> Void

    @State private var filter: DistanceFilter = .ten

    // MARK: - Distance
    
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

    // MARK: - Filtering

    private var filteredIslandsWithTimes: [IslandWithTimes] {

        islandsWithMatTimes.compactMap { (island, times) -> IslandWithTimes? in

            if let miles = distance(for: island),
               miles > filter.rawValue {
                return nil
            }

            guard let selectedDay = selectedDay else { return nil }

            let filteredTimes = times.filter {
                $0.appDayOfWeek?.day == selectedDay.rawValue
            }

            guard !filteredTimes.isEmpty else { return nil }

            return IslandWithTimes(island: island, times: filteredTimes)
        }
    }
    
    // MARK: - Sorting
    
    private var sortedIslandsWithTimes: [IslandWithTimes] {

        filteredIslandsWithTimes.sorted {

            let d1 = distance(for: $0.island) ?? .greatestFiniteMagnitude
            let d2 = distance(for: $1.island) ?? .greatestFiniteMagnitude

            return d1 < d2
        }
    }
    
    private var totalClasses: Int {
        sortedIslandsWithTimes.reduce(0) { $0 + $1.times.count }
    }

    // MARK: - UI
    
    var body: some View {

        NavigationStack {

            VStack {

                DayPickerView(selectedDay: $selectedDay)
                    .padding(.horizontal)

                Picker("Distance", selection: $filter) {
                    ForEach(DistanceFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

  
                List {

                    ForEach(Array(sortedIslandsWithTimes.enumerated()), id: \.element.id) { _, item in
                        
                        let island = item.island
                        let times = item.times
                        let nextClass = MatTime.nextClass(from: times, day: selectedDay)
                        
                        Button {
                            onSelect(island)
                        } label: {

                            VStack(alignment: .leading, spacing: 8) {

                                IslandListItem(
                                    island: island,
                                    selectedIsland: .constant(nil)
                                )

                                // ✅ NEXT CLASS DISPLAY
                                if let next = nextClass {
                                    Text("Next Class: \(next.nextClassLabel)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }

                                if let miles = distance(for: island) {
                                    Text("\(miles, specifier: "%.1f") miles away")
                                        .font(.caption2)
                                        .foregroundColor(.accentColor.opacity(0.6))
                                }

                                VStack(alignment: .leading, spacing: 4) {

                                    ForEach(times.sorted(by: MatTime.scheduleSort), id: \.objectID) { matTime in
                                        HStack {
                                            Text(matTime.displayTime)
                                                .font(.caption)
                                                .bold()

                                            Text(matTime.formattedHeader(includeDay: false))
                                                .font(.caption)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Classes (\(totalClasses))")
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
