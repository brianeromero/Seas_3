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

    @State private var equatableRegionWrapper = EquatableMKCoordinateRegion(
        region: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )

    @ObservedObject private var userLocationMapViewModel = UserLocationMapViewModel.shared
    @EnvironmentObject var viewModel: AppDayOfWeekViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @State private var radius: Double = 10.0
    @State private var errorMessage: String?
    @State private var selectedDay: DayOfWeek? = .monday
    @State private var showModal: Bool = false

    var body: some View {
        GeometryReader { geo in
            VStack {
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { _, _ in
                        Task { await updateIslandsAndRegion() }
                    }

                ErrorView(errorMessage: $errorMessage)

                SearchableClusterMap(
                    region: $equatableRegionWrapper.region,
                    markers: viewModel.displayedMarkers,
                    onRegionSearchRequested: handleRegionSearch,
                    onMarkerTap: handleMarkerTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                updateRegion(center: location.coordinate)
                Task { await updateIslandsAndRegion() }
            }
            .onChange(of: selectedIsland) { _, newValue in
                updateSelectedIsland(from: newValue)
            }
        }
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

    private func handleRegionSearch(_ newRegion: MKCoordinateRegion) {
        guard let selectedDay else { return }

        Task {
            // Fetch islands for the selected day
            await viewModel.fetchIslands(forDay: selectedDay)
            // Update clusters automatically for the new region
            await MainActor.run {
                viewModel.updateClusters(for: newRegion)
            }
        }
    }

    private func handleMarkerTap(_ marker: CustomMapMarker) {
        guard let island = marker.pirateIsland else { return }
        selectedIsland = island
        showModal = true
    }

    // MARK: - Data Updates

    private func updateIslandsAndRegion() async {
        guard let selectedDay else {
            errorMessage = "Day of week is not selected."
            return
        }

        // 1️⃣ Fetch islands for the selected day
        await viewModel.fetchIslands(forDay: selectedDay)

        // 2️⃣ Update clusters for the current region immediately
        await MainActor.run {
            viewModel.updateClusters(for: equatableRegionWrapper.region)
        }

        // 3️⃣ Optionally, center map on user location
        if let location = userLocationMapViewModel.userLocation {
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
        withAnimation {
            equatableRegionWrapper.region = MapUtils.updateRegion(
                markers: viewModel.islandsWithMatTimes.map {
                    CustomMapMarker(
                        id: $0.0.islandID ?? UUID().uuidString, // ✅ Use UUID string
                        coordinate: CLLocationCoordinate2D(
                            latitude: $0.0.latitude,
                            longitude: $0.0.longitude
                        ),
                        title: $0.0.islandName ?? "Unnamed Gym",
                        pirateIsland: $0.0
                    )
                },
                selectedRadius: radius,
                center: center
            )
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
