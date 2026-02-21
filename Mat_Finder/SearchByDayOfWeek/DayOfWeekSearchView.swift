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

    var body: some View {
        GeometryReader { geo in
            VStack {
                DayPickerView(selectedDay: $selectedDay)
                    .onChange(of: selectedDay) { _, _ in
                        Task { await updateIslandsAndRegion() }
                    }

                ErrorView(errorMessage: $errorMessage)

                IslandMKMapView(
                    islands: viewModel.islandsWithMatTimes.map(\.0),
                    selectedIsland: $selectedIsland,
                    showModal: $showModal,
                    region: region
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


    // MARK: - Data Updates

    private func updateIslandsAndRegion() async {

        guard let selectedDay else {
            errorMessage = "Day of week is not selected."
            return
        }

        await viewModel.fetchIslands(forDay: selectedDay)

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
