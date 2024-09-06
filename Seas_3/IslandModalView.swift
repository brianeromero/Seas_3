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

                    if let island = selectedIsland {
                        if scheduleExists {
                            NavigationLink(
                                destination: ViewScheduleForIsland(
                                    viewModel: viewModel,
                                    island: island
                                )
                            ) {
                                Text("View Schedule")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 20)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No schedule is available for this Gym; be the first to enter.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                NavigationLink(destination: DaysOfWeekFormView(
                                    viewModel: viewModel,
                                    selectedIsland: $selectedIsland,
                                    selectedMatTime: .constant(nil)
                                )) {
                                    Text("Add Schedule")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.top, 20)
                        }
                    } else {
                        Text("Select an island first")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    }

                    if !reviews.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Average Rating:")
                                    .font(.system(size: 12))
                                Spacer()
                                Text(averageStarRating)
                                    .font(.system(size: 12))
                            }
                            
                            NavigationLink(destination: ViewReviewforIsland(selectedIsland: selectedIsland)) {
                                Text("View Reviews")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No reviews available.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            NavigationLink(destination: GymMatReviewView(
                                selectedIsland: $selectedIsland,
                                isPresented: $showModal,
                                enterZipCodeViewModel: enterZipCodeViewModel
                            )) {
                                Text("Leave a Review")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.top, 20)
                    }

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
                .shadow(radius: 10)
                .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.6)
            }
        }
        .interactiveDismissDisabled(false)
        .onAppear {
            guard let island = selectedIsland, let day = selectedDay else {
                return
            }
            Task {
                let fetchedSchedules = PersistenceController.shared.fetchAppDayOfWeekForIslandAndDay(for: island, day: day)
                islandSchedules = [(island, fetchedSchedules.flatMap { $0.matTimes?.allObjects as? [MatTime] ?? [] })]
                scheduleExists = !fetchedSchedules.isEmpty
            }
        }
    }
}

struct IslandModalView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock or dummy instances for all parameters
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: PersistenceController.preview.container.viewContext
        )
        
        let mockIsland = PirateIsland() // Ensure PirateIsland() is properly initialized

        let mockAppDayOfWeekViewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland, // Pass the mock PirateIsland instance
            repository: AppDayOfWeekRepository.shared,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        
        return IslandModalView(
            customMapMarker: CustomMapMarker(
                id: UUID(),
                coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                title: "Title",
                pirateIsland: mockIsland // Pass a mock PirateIsland instance
            ),
            islandName: "Big Bad Island",
            islandLocation: "Island Address",
            formattedCoordinates: "12.3456, 78.9012",
            createdTimestamp: "2022-01-01 12:00:00",
            formattedTimestamp: "2022-01-01 12:00:00",
            gymWebsite: URL(string: "https://www.example.com"),
            reviews: [Review(), Review()],
            averageStarRating: "4.5",
            dayOfWeekData: [.monday, .tuesday, .wednesday],
            selectedAppDayOfWeek: .constant(nil),
            selectedIsland: .constant(mockIsland), // Pass a mock PirateIsland instance
            viewModel: mockAppDayOfWeekViewModel,
            selectedDay: .constant(.monday),
            showModal: .constant(true),
            enterZipCodeViewModel: mockEnterZipCodeViewModel // Pass the mock EnterZipCodeViewModel instance
        )
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
