//
//  ViewScheduleForIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 8/28/24.
//

import Foundation
import SwiftUI
import CoreData

struct ViewScheduleForIsland: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    let island: PirateIsland
    
    var body: some View {
        VStack {
            Text("Schedules for \(island.islandName ?? "Unknown Gym")")
                .font(.title)
                .padding()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        Button(action: {
                            viewModel.selectedDay = day
                            Task {
                                await viewModel.loadSchedules(for: island)
                            }
                        }) {
                            Text(day.displayName)
                                .font(.headline)
                                .foregroundColor(viewModel.selectedDay == day ? .blue : .black)
                                .padding()
                        }
                    }
                }
            }
            
            Text("Schedule Mat Times for \(viewModel.selectedDay?.displayName ?? "Select a Day")")
                .font(.title2)
                .padding()

            // Fixed height for the section
            VStack {
                if let day = viewModel.selectedDay {
                    if !viewModel.matTimesForDay.isEmpty {
                        ScheduledMatTimesSection(
                            island: island,
                            day: day,
                            viewModel: viewModel,
                            matTimesForDay: $viewModel.matTimesForDay,
                            selectedDay: $viewModel.selectedDay
                        )
                        .frame(height: 250) // Set a fixed height for the section
                        
                    } else {
                        Text("No mat times available for \(day.displayName) at \(island.islandName ?? "Unknown Gym").")
                            .foregroundColor(.gray)
                            .frame(height: 200) // Match the height of the scheduled section
                    }
                } else {
                    Text("Please select a day to view the schedule.")
                        .foregroundColor(.gray)
                        .frame(height: 200) // Match the height of the scheduled section
                }
            }
            .frame(maxWidth: .infinity) // Ensure it takes full width
            .background(Color(UIColor.systemGroupedBackground)) // Optional: background color for better visibility
        }
        .onAppear {
            if viewModel.selectedDay == nil {
                viewModel.selectedDay = DayOfWeek.monday
            }
            Task {
                await viewModel.loadSchedules(for: island)
            }
            print("Loaded schedules for island: \(island.islandName ?? "Unknown")")
            print("Loaded schedules: \(viewModel.matTimesForDay.count) mat times")
        }
    }
}

// MARK: - Preview
struct ViewScheduleForIsland_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        // Create a mock PirateIsland
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Paradise Island"
        mockIsland.islandLocation = "Tropical Region"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        
        // Create a mock AppDayOfWeek
        let mockDayOfWeek = AppDayOfWeek(context: context)
        mockDayOfWeek.day = "Monday"
        mockDayOfWeek.name = "Monday Schedule"
        mockDayOfWeek.pIsland = mockIsland // Associate AppDayOfWeek with PirateIsland
        
        // Create mock MatTimes
        let mockMatTime1 = MatTime(context: context)
        mockMatTime1.time = "10:00 AM"
        mockMatTime1.gi = true
        mockMatTime1.noGi = false
        mockMatTime1.openMat = false
        mockMatTime1.appDayOfWeek = mockDayOfWeek // Associate MatTime with AppDayOfWeek
        
        let mockMatTime2 = MatTime(context: context)
        mockMatTime2.time = "01:00 PM"
        mockMatTime2.gi = false
        mockMatTime2.noGi = true
        mockMatTime2.openMat = false
        mockMatTime2.appDayOfWeek = mockDayOfWeek // Associate MatTime with AppDayOfWeek
        
        // Create a mock AppDayOfWeekViewModel
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: repository,
            enterZipCodeViewModel: EnterZipCodeViewModel(
                repository: repository,
                persistenceController: persistenceController
            )
        )
        
        // Simulate data loading
        Task {
            await viewModel.loadSchedules(for: mockIsland) // Load schedules for the mock island
            viewModel.selectedDay = DayOfWeek.monday
        }
        
        // Provide the view with the mock data
        return ViewScheduleForIsland(viewModel: viewModel, island: mockIsland)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
