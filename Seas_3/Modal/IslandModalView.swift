//
//  IslandModalView.swift
//  Seas_3
//
//  Created by Brian Romero on 8/29/24.
//

import Foundation
import SwiftUI
import CoreLocation

struct IslandModalView: View {
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Binding var selectedDay: DayOfWeek?
    @Binding var showModal: Bool
    @State private var isLoadingData: Bool = false
    @State private var showReview: Bool = false  // Add showReview here
    var isLoading: Bool {
        islandSchedules.isEmpty && !scheduleExists || isLoadingData
    }
    let customMapMarker: CustomMapMarker?
    @State private var scheduleExists: Bool = false
    @State private var islandSchedules: [(PirateIsland, [MatTime])] = []
    let islandName: String
    let islandLocation: String
    let formattedCoordinates: String
    let createdTimestamp: String
    let formattedTimestamp: String
    let gymWebsite: URL?
    let reviews: [Review]
    let dayOfWeekData: [DayOfWeek]
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @StateObject private var authViewModel = AuthViewModel(
        managedObjectContext: PersistenceController.preview.container.viewContext
    )

    init(
        customMapMarker: CustomMapMarker?,
        islandName: String,
        islandLocation: String,
        formattedCoordinates: String,
        createdTimestamp: String,
        formattedTimestamp: String,
        gymWebsite: URL?,
        reviews: [Review],
        dayOfWeekData: [DayOfWeek],
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel,
        selectedDay: Binding<DayOfWeek?>,
        showModal: Binding<Bool>,
        enterZipCodeViewModel: EnterZipCodeViewModel
    ) {
        self.customMapMarker = customMapMarker
        self.islandName = islandName
        self.islandLocation = islandLocation
        self.formattedCoordinates = formattedCoordinates
        self.createdTimestamp = createdTimestamp
        self.formattedTimestamp = formattedTimestamp
        self.gymWebsite = gymWebsite
        self.reviews = reviews
        self.dayOfWeekData = dayOfWeekData
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
        self._selectedDay = selectedDay
        self._showModal = showModal
        self.enterZipCodeViewModel = enterZipCodeViewModel
    }

    // Replace the manual average rating calculation with the static method
    private var averageStarRating: Double {
        guard let island = selectedIsland else { return 0.0 }

        // Fetch the average rating using the ReviewUtils
        return Double(ReviewUtils.fetchAverageRating(for: island, in: island.managedObjectContext!))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showModal = false
                    }

                if isLoadingData {
                    ProgressView("Loading schedules...")
                } else if let selectedIsland = selectedIsland, let _ = selectedDay {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(islandName)
                            .font(.system(size: 14))
                            .bold()

                        Text(islandLocation)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        if let gymWebsite = gymWebsite {
                            HStack {
                                Text("Website:")
                                    .font(.system(size: 12))
                                Spacer()
                                Link("Visit Website", destination: gymWebsite)
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 10)
                        } else {
                            Text("No website available.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                        }

                        if scheduleExists {
                            NavigationLink(
                                destination: ViewScheduleForIsland(
                                    viewModel: viewModel,
                                    island: selectedIsland
                                )
                            ) {
                                Text("View Schedule")
                            }
                        } else {
                            Text("No schedules found for this Gym.")
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            if !reviews.isEmpty {
                                HStack {
                                    Text("Average Rating:")
                                    Spacer()
                                    Text(String(format: "%.1f", averageStarRating))
                                }

                                NavigationLink(destination: ViewReviewforIsland(
                                    showReview: $showReview,
                                    selectedIsland: $selectedIsland,
                                    enterZipCodeViewModel: enterZipCodeViewModel,
                                    authViewModel: authViewModel
                                )) {
                                    Text("View Reviews")
                                }

                            } else {
                                Text("No reviews available.")
                                    .foregroundColor(.secondary)

                                NavigationLink(destination: GymMatReviewView(
                                    localSelectedIsland: .constant(selectedIsland),
                                    enterZipCodeViewModel: enterZipCodeViewModel, authViewModel: authViewModel,
                                    onIslandChange: { newIsland in
                                        // Handle island change
                                    }
                                )) {
                                    HStack {
                                        Text("Be the first to write a review!")
                                        Image(systemName: "pencil.and.ellipsis.rectangle")
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.top, 20)

                        Spacer()

                        Button(action: {
                            showModal = false
                        }) {
                            Text("Close")
                                .font(.system(size: 12))
                                .padding(10)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                                .padding(.horizontal, 10)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                } else {
                    Text("Error: selectedIsland or selectedDay is nil.")
                        .font(.system(size: 14))
                        .bold()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
            }
        }
        .interactiveDismissDisabled(false)
        .onAppear {
            isLoadingData = true
            guard let island = selectedIsland else {
                isLoadingData = false
                return
            }
            Task {
                await viewModel.loadSchedules(for: island)
                scheduleExists = !viewModel.schedules.isEmpty
                isLoadingData = false
            }
        }
    }
}
