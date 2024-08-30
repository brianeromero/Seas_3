//
//  IslandModalView.swift
//  Seas_3
//
//  Created by Brian Romero on 8/29/24.
//

import Foundation
import SwiftUI

struct IslandModalView: View {
    @Binding var width: CGFloat
    @Binding var height: CGFloat
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
    @Binding var selectedDay: DayOfWeek?
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var showModal: Bool

    init(
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
        width: Binding<CGFloat>,
        height: Binding<CGFloat>
    ) {
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
        self._width = width
        self._height = height
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Information
                    Text(islandName)
                        .font(.system(size: 14)) // Increased font size
                        .bold()
                    Text(islandLocation)
                        .font(.system(size: 12)) // Slightly increased font size
                        .foregroundColor(.secondary)

                    // Website (if available)
                    if let gymWebsite = gymWebsite {
                        HStack {
                            Text("Website:")
                                .font(.system(size: 12))
                            Spacer()
                            Link("Visit Website", destination: gymWebsite)
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                    } else {
                        Text("No website available.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    // Schedule NavigationLink
                    Group {
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
                                        .padding(.top, 10)
                                }
                            } else {
                                Text("No schedule is available for this Gym; be the first to enter.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Select an island first")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

         /*           // Scheduled Mat Times Section
                    if let selectedDay = selectedDay, let selectedIsland = selectedIsland {
                        ScheduledMatTimesSection(
                            island: selectedIsland,
                            day: selectedDay, // Pass the unwrapped value directly
                            viewModel: viewModel,
                            matTimesForDay: $viewModel.matTimesForDay,
                            selectedDay: .constant(selectedDay) // Create a binding from the unwrapped value
                        )
                    } else {
                        Text("Please select a day and island to view the schedule.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
*/
                    // Reviews (if available)
                    if !reviews.isEmpty {
                        HStack {
                            Text("Average Rating:")
                                .font(.system(size: 12))
                            Spacer()
                            Text(averageStarRating)
                                .font(.system(size: 12))
                        }
                    } else {
                        Text("No reviews available.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .onAppear {
                guard let island = selectedIsland, let day = selectedDay else {
                    return
                }
                Task {
                    let fetchedSchedules = PersistenceController.shared.fetchAppDayOfWeekForIslandAndDay(for: island, day: day)
                    // Update the islandSchedules and scheduleExists accordingly
                    islandSchedules = [(island, fetchedSchedules.flatMap { $0.matTimes?.allObjects as? [MatTime] ?? [] })]
                    scheduleExists = !fetchedSchedules.isEmpty
                }
            }
            .frame(width: width, height: height)
        }
    }
}
