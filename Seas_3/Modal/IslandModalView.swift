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
    @Environment(\.managedObjectContext) var viewContext
    @ObservedObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @Binding var selectedDay: DayOfWeek?
    @Binding var showModal: Bool
    @State private var isLoadingData: Bool = false
    @State private var showReview: Bool = false

    @State private var currentAverageStarRating: Double = 0.0
    @State private var currentReviews: [Review] = []

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

    let dayOfWeekData: [DayOfWeek]
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @ObservedObject private var authViewModel = AuthViewModel.shared

    init(
        customMapMarker: CustomMapMarker?,
        islandName: String,
        islandLocation: String,
        formattedCoordinates: String,
        createdTimestamp: String,
        formattedTimestamp: String,
        gymWebsite: URL?,
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
        self.dayOfWeekData = dayOfWeekData
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
        self._selectedDay = selectedDay
        self._showModal = showModal
        self.enterZipCodeViewModel = enterZipCodeViewModel
    }

    
    var body: some View {
        // Apply Scenario A: NavigationView wraps the content of the modal
        NavigationView {
            ZStack {
                // Dimming background - using adaptive color for better appearance
                // Color.primary.opacity(0.2) // This dims the background behind the modal.
                                          // It should be fine as it adapts, but the modal itself needs clarity.
                Color.black.opacity(0.4) // Using explicit black for dimming overlay to ensure it's dark enough

                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showModal = false // Dismiss modal by tapping outside
                    }

                // Conditional content based on loading state and data availability
                if isLoadingData {
                    ProgressView("Loading schedules...")
                        .padding()
                        .background(Color(.systemBackground)) // Adaptive background color
                        .cornerRadius(10)
                } else if let selectedIsland = selectedIsland, let _ = selectedDay {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(islandName)
                            .font(.system(size: 14))
                            .bold()
                            .foregroundColor(.primary) // Ensure it uses primary color for text

                        Text(islandLocation)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary) // Ensure it uses secondary color for text

                        if let gymWebsite = gymWebsite {
                            HStack {
                                Text("Website:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Spacer()
                                Link("Visit Website", destination: gymWebsite)
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor) // Uses accent color for links
                            }
                            .padding(.top, 10)
                        } else {
                            Text("No website available.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.top, 10)
                        }

                        // View Schedule Link
                        if scheduleExists {
                            NavigationLink(
                                destination: ViewScheduleForIsland(
                                    viewModel: viewModel,
                                    island: selectedIsland
                                )
                            ) {
                                Text("View Schedule")
                                    .foregroundColor(.accentColor) // Uses accent color for links
                            }
                        } else {
                            Text("No schedules found for this Gym.")
                                .foregroundColor(.secondary)
                        }

                        // Reviews Section
                        VStack(alignment: .leading, spacing: 8) {
                            if !currentReviews.isEmpty {
                                HStack {
                                    Text("Average Rating:")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(String(format: "%.1f", currentAverageStarRating))
                                        .foregroundColor(.primary)
                                }

                                NavigationLink(destination: ViewReviewforIsland(
                                    showReview: $showReview,
                                    selectedIsland: $selectedIsland,
                                    enterZipCodeViewModel: enterZipCodeViewModel,
                                    authViewModel: authViewModel
                                )) {
                                    Text("View Reviews")
                                        .foregroundColor(.accentColor) // Uses accent color for links
                                }

                            } else {
                                Text("No reviews available.")
                                    .foregroundColor(.secondary)

                                NavigationLink(destination: GymMatReviewView(
                                    localSelectedIsland: .constant(selectedIsland),
                                    enterZipCodeViewModel: enterZipCodeViewModel,
                                    authViewModel: authViewModel,
                                    onIslandChange: { newIsland in
                                        // Handle island change if needed after review submission
                                    }
                                )) {
                                    HStack {
                                        Text("Be the first to write a review!")
                                        Image(systemName: "pencil.and.ellipsis.rectangle")
                                    }
                                    .foregroundColor(.accentColor) // Uses accent color for links
                                }
                            }
                        }
                        .padding(.top, 20)

                        Spacer()

                        // Close Button (aligned to leading edge, as the rest of the VStack)
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
                    .background(Color(.systemBackground)) // IMPORTANT: Ensure this is Color(.systemBackground)
                    .cornerRadius(10)
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                } else {
                    Text("Error: selectedIsland or selectedDay is nil.")
                        .font(.system(size: 14))
                        .bold()
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
            // Add a toolbar for a dismiss button, typical for NavigationViews in sheets
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Dismiss") {
                        showModal = false
                    }
                }
            }
            // Optional: Set a title for the modal's navigation bar
            .navigationTitle(selectedIsland?.islandName ?? "Island Details")
            .navigationBarTitleDisplayMode(.inline) // Makes the title smaller
        }
        .interactiveDismissDisabled(false) // Allows swipe-down dismissal if presented as a sheet
        .onAppear {
            isLoadingData = true
            guard let island = selectedIsland else {
                isLoadingData = false
                return
            }
            Task {
                await viewModel.loadSchedules(for: island)
                scheduleExists = !viewModel.schedules.isEmpty

                // Fetch reviews and average rating
                let fetchedAvgRating = await ReviewUtils.fetchAverageRating(for: island, in: viewContext, callerFunction: "IslandModalView.onAppear")
                let fetchedReviews = await ReviewUtils.fetchReviews(for: island, in: viewContext, callerFunction: "IslandModalView.onAppear")

                // Update @State properties on the MainActor
                await MainActor.run {
                    self.currentAverageStarRating = Double(fetchedAvgRating)
                    self.currentReviews = fetchedReviews
                }

                isLoadingData = false
            }
        }
    }
}
