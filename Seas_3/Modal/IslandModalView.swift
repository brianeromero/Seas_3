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
    
    @Binding var navigationPath: NavigationPath


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
        enterZipCodeViewModel: EnterZipCodeViewModel,
        navigationPath: Binding<NavigationPath>
        
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
        self._navigationPath = navigationPath

    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showModal = false
                    }

                // Conditional content based on loading state and data availability
                contentView
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Dismiss") {
                        showModal = false
                    }
                }
            }
            .navigationTitle(selectedIsland?.islandName ?? "Island Details")
            .navigationBarTitleDisplayMode(.inline)
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

                let fetchedAvgRating = await ReviewUtils.fetchAverageRating(for: island, in: viewContext, callerFunction: "IslandModalView.onAppear")
                let fetchedReviews = await ReviewUtils.fetchReviews(for: island, in: viewContext, callerFunction: "IslandModalView.onAppear")

                await MainActor.run {
                    self.currentAverageStarRating = Double(fetchedAvgRating)
                    self.currentReviews = fetchedReviews
                }
                isLoadingData = false
            }
        }
    }

    // MARK: - Extracted Subviews and NavigationLink Destinations

    @ViewBuilder
    private var contentView: some View {
        if isLoadingData {
            ProgressView("Loading schedules...")
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
        } else if let island = selectedIsland, selectedDay != nil { // Use 'island' directly in the if-let
            modalContent(island: island)
        } else {
            Text("Error: selectedIsland or selectedDay is nil.")
                .font(.system(size: 14))
                .bold()
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
        }
    }

    private func modalContent(island: PirateIsland) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(islandName)
                .font(.system(size: 14))
                .bold()
                .foregroundColor(.primary)

            Text(islandLocation)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            websiteSection

            scheduleSection(for: island) // Pass island to schedule section

            reviewsSection

            Spacer()

            closeButton
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
    }

    private var websiteSection: some View {
        Group {
            if let gymWebsite = gymWebsite {
                HStack {
                    Text("Website:")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Spacer()
                    Link("Visit Website", destination: gymWebsite)
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 10)
            } else {
                Text("No website available.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            }
        }
    }

    private func scheduleSection(for island: PirateIsland) -> some View {
        Group {
            if scheduleExists {
                NavigationLink(
                    destination: ViewScheduleForIsland(
                        viewModel: viewModel,
                        island: island // Use the passed island
                    )
                ) {
                    Text("View Schedule")
                        .foregroundColor(.accentColor)
                }
            } else {
                Text("No schedules found for this Gym.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !currentReviews.isEmpty {
                HStack {
                    Text("Average Rating:")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.1f", currentAverageStarRating))
                        .foregroundColor(.primary)
                }

                // Fix for "Cannot convert value of type 'PirateIsland' to expected argument type 'String'"
                // You need to pass the objectID.uriRepresentation().absoluteString
                NavigationLink(value: AppScreen.viewAllReviews(selectedIsland!.objectID.uriRepresentation().absoluteString)) {
                    Text("View All Reviews")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

            } else {
                Text("No reviews available.")
                    .foregroundColor(.secondary)

                // Fix for "Cannot find 'island' in scope"
                // You should be using `selectedIsland` here.
                // Also ensure it's safely unwrapped or checked, although `!` is used here
                // assuming `selectedIsland` won't be nil in this context.
                NavigationLink(value: AppScreen.review(selectedIsland!.objectID.uriRepresentation().absoluteString)) {
                    HStack {
                        Text("Be the first to write a review!")
                        Image(systemName: "pencil.and.ellipsis.rectangle")
                    }
                    .font(.headline)
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }
    
    private var closeButton: some View {
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
}
