//
//  ViewScheduleForIsland.swift
//  Mat_Finder
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
                                .padding(.horizontal, 10) // Add horizontal padding for a more button-like feel
                                .padding(.vertical, 5) // Add vertical padding
                                .background(viewModel.selectedDay == day ? Color.accentColor : Color.clear) // Use accentColor for selected
                                .foregroundColor(viewModel.selectedDay == day ? .white : .primary) // .white for selected, .primary for unselected
                                .cornerRadius(8) // Add corner radius for rounded appearance
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            viewModel.selectedDay == day ? Color.accentColor : Color.secondary.opacity(0.5),
                                            lineWidth: 1
                                        ) // Add a subtle border for unselected days
                                )
                        }
                    }
                }
                .padding(.horizontal) // Padding for the scroll view content
            }
            .padding(.vertical, 8) // Padding around the day selector
            
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
                        Text("No mat times available for3 \(day.displayName) at \(island.islandName ?? "Unknown Gym").")
                            .foregroundColor(.gray)
                            .frame(height: 200) // Match the height of the scheduled section
                    }
                } else {
                    Text("Please select a day to view the schedule.")
                        .foregroundColor(.gray)
                        .frame(height: 200) // Match the height of the scheduled section
                }
            }
            .frame(maxWidth: .infinity)
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
