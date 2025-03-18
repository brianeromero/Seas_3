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

    // Remove averageStarRating from initializer
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

    // Calculate average star rating here
    private var averageStarRating: Double {
        ReviewUtils.averageStarRating(for: reviews)
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
                                    Text(String(format: "%.1f", averageStarRating)) // Convert the Double to String
                                }

                                NavigationLink(destination: ViewReviewforIsland(
                                    showReview: $showReview, selectedIsland: $selectedIsland,
                                    enterZipCodeViewModel: enterZipCodeViewModel
                                )) {
                                    Text("View Reviews")
                                }
                            } else {
                                Text("No reviews available.")
                                    .foregroundColor(.secondary)

                                NavigationLink(destination: GymMatReviewView(
                                    localSelectedIsland: .constant(selectedIsland),
                                    enterZipCodeViewModel: enterZipCodeViewModel,
                                    onIslandChange: { newIsland in
                                        // Handle island change
                                    }
                                )) {
                                    HStack {
                                        Text("Be the first to write a review!")
                                        Image(systemName: "pencil.and.ellipsis.rectangle")
                                    }
                                    .foregroundColor(.blue) // Ensures both icon and text are blue
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



struct IslandModalView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        let mockIsland = PirateIsland(
            context: persistenceController.container.viewContext
        )
        mockIsland.islandName = "Big Bad Island"
        mockIsland.islandLocation = "Gym Address"
        mockIsland.latitude = 37.7749
        mockIsland.longitude = -122.4194
        mockIsland.createdTimestamp = Date()
        mockIsland.lastModifiedTimestamp = Date()

        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: persistenceController
        )
        let mockAppDayOfWeekViewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: MockAppDayOfWeekRepository(persistenceController: persistenceController),
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )

        let mockCustomMapMarker = CustomMapMarker(
            id: UUID(),
            coordinate: CLLocationCoordinate2D(latitude: mockIsland.latitude, longitude: mockIsland.longitude),
            title: "Title",
            pirateIsland: mockIsland
        )

        // Create mock reviews
        let mockReview1 = Review(context: persistenceController.container.viewContext)
        mockReview1.stars = 5
        mockReview1.createdTimestamp = Date()

        let mockReview2 = Review(context: persistenceController.container.viewContext)
        mockReview2.stars = 4
        mockReview2.createdTimestamp = Date()

        let mockReviews = [mockReview1, mockReview2]

        let islandModalView = IslandModalView(
            customMapMarker: mockCustomMapMarker,
            islandName: mockIsland.islandName ?? "",
            islandLocation: mockIsland.islandLocation ?? "",
            formattedCoordinates: "\(mockIsland.latitude), \(mockIsland.longitude)",
            createdTimestamp: "2022-01-01 12:00:00",
            formattedTimestamp: "2022-01-01 12:00:00",
            gymWebsite: URL(string: "https://www.example.com"),
            reviews: mockReviews,
            dayOfWeekData: [.monday, .tuesday, .wednesday],
            selectedAppDayOfWeek: .constant(nil),
            selectedIsland: .constant(mockIsland),
            viewModel: mockAppDayOfWeekViewModel,
            selectedDay: .constant(.monday),
            showModal: .constant(true),
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )

        return islandModalView
    }
}
