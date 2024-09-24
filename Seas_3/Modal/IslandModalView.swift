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
    let averageStarRating: String
    let dayOfWeekData: [DayOfWeek]
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?

    init(
        customMapMarker: CustomMapMarker?,
        islandName: String,
        islandLocation: String,
        formattedCoordinates: String,
        createdTimestamp: String,
        formattedTimestamp: String,
        gymWebsite: URL?,
        reviews: [Review],
        averageStarRating: String,
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
        self.averageStarRating = averageStarRating
        self.dayOfWeekData = dayOfWeekData
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
        self._selectedDay = selectedDay
        self._showModal = showModal
        self.enterZipCodeViewModel = enterZipCodeViewModel
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

                        // Check if gymWebsite is available and display accordingly
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

                        // Display reviews or option to leave a review
                        VStack(alignment: .leading, spacing: 8) {
                            if !reviews.isEmpty {
                                HStack {
                                    Text("Average Rating:")
                                    Spacer()
                                    Text(averageStarRating)
                                }

                                NavigationLink(destination: ViewReviewforIsland()) {
                                    Text("View Reviews")
                                }

                            } else {
                                Text("No reviews available.")
                                    .foregroundColor(.secondary)

                                NavigationLink(destination: GymMatReviewView(
                                    selectedIsland: $selectedIsland,
                                    isPresented: $showModal,
                                    enterZipCodeViewModel: enterZipCodeViewModel
                                )) {
                                    Text("Leave a Review")
                                }
                            }
                        }
                        .padding(.top, 20)

                        Spacer()

                        Button(action: {
                            print("Close button tapped")
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
                    .shadow(radius: 10)
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
                } else {
                    Text("Error: selectedIsland or selectedDay is nil.")
                        .font(.system(size: 14))
                        .bold()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
        .interactiveDismissDisabled(false)
        .onAppear {
            isLoadingData = true
            guard let island = selectedIsland, let day = selectedDay else {
                print("Error: selectedIsland or selectedDay is nil.")
                isLoadingData = false
                return
            }
            print("Fetching schedules for island: \(island.islandName ?? "Unknown") on day: \(day.displayName)")
            Task {
                let fetchedSchedules = PersistenceController.shared.fetchAppDayOfWeekForIslandAndDay(for: island, day: day)
                islandSchedules = [(island, fetchedSchedules.flatMap { $0.matTimes?.allObjects as? [MatTime] ?? [] })]
                scheduleExists = !fetchedSchedules.isEmpty
                isLoadingData = false
                print("Schedules loaded: \(islandSchedules.count) schedules")
            }
        }
    }

}

struct IslandModalView_Previews: PreviewProvider {
    static var previews: some View {
        let mockIsland = PirateIsland(
            context: PersistenceController.preview.container.viewContext
        )
        mockIsland.islandName = "Big Bad Island"
        mockIsland.islandLocation = "Island Address"
        mockIsland.latitude = 37.7749
        mockIsland.longitude = -122.4194
        mockIsland.createdTimestamp = Date()
        mockIsland.lastModifiedTimestamp = Date()

        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: PersistenceController.preview.container.viewContext
        )
        let mockAppDayOfWeekViewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )

        let mockCustomMapMarker = CustomMapMarker(
            id: UUID(),
            coordinate: CLLocationCoordinate2D(latitude: mockIsland.latitude, longitude: mockIsland.longitude),
            title: "Title",
            pirateIsland: mockIsland
        )

        let mockReviews = [Review(), Review()]

        let islandModalView = IslandModalView(
            customMapMarker: mockCustomMapMarker,
            islandName: mockIsland.islandName ?? "",
            islandLocation: mockIsland.islandLocation ?? "",
            formattedCoordinates: "\(mockIsland.latitude), \(mockIsland.longitude)",
            createdTimestamp: "2022-01-01 12:00:00",
            formattedTimestamp: "2022-01-01 12:00:00",
            gymWebsite: URL(string: "https://www.example.com"),
            reviews: mockReviews,
            averageStarRating: "4.5",
            dayOfWeekData: [.monday, .tuesday, .wednesday],
            selectedAppDayOfWeek: .constant(nil),
            selectedIsland: .constant(mockIsland),
            viewModel: mockAppDayOfWeekViewModel,
            selectedDay: .constant(.monday),
            showModal: .constant(true),
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )

        return islandModalView
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
