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
    
    @State private var showingAddSchedule = false

    @State private var selectedIslandID: String?

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    let island: PirateIsland


    var body: some View {
        
        VStack(alignment: .leading, spacing: 24) {
            
            headerSection
            
            daySelectorSection
            
            scheduleSection
            
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        
        .safeAreaInset(edge: .bottom) {
            
            addScheduleButton
            
        }
        
        .alert(alertTitle, isPresented: $showAlert) {
            
            Button("OK", role: .cancel) { }
            
        } message: {
            
            Text(alertMessage)
            
        }
        
        .sheet(
            isPresented: $showingAddSchedule,
            onDismiss: {
                Task {
                    await viewModel.loadSchedules(for: island)
                }
            }
        ) {
            NavigationStack {

                AddNewMatTimeSection2(

                    selectedIslandID: $selectedIslandID,

                    islands: [island],

                    viewModel: viewModel,

                    showAlert: $showAlert,

                    alertTitle: $alertTitle,

                    alertMessage: $alertMessage,

                    selectIslandAndDay: selectIslandAndDay

                )

            }
        }
        
        .onAppear {

            selectedIslandID = island.islandID   // ✅ ADD THIS

            if viewModel.selectedDay == nil {
                viewModel.selectedDay = .monday
            }

            Task {

                await viewModel.loadSchedules(for: island)

            }

        }
    }
}


private extension ViewScheduleForIsland {

    var headerSection: some View {

        Text(island.islandName ?? "Unknown Gym")
            .font(.title2)
            .fontWeight(.semibold)
    }

}

private extension ViewScheduleForIsland {

    var daySelectorSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Select a Day to View Available Mat Times")
                .font(.caption)
                .foregroundColor(.secondary)


            ScheduleDaySelector(
                island: island,
                selectedDay: $viewModel.selectedDay,
                viewModel: viewModel
            )

        }

    }

}


private extension ViewScheduleForIsland {

    var scheduleSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            if let selectedDay = viewModel.selectedDay {

                let matTimes =
                    viewModel.matTimesForDay[selectedDay] ?? []

                if matTimes.isEmpty {

                    Text("""
                    No mat times entered for \(selectedDay.displayName) at \(island.islandName ?? "").
                    """)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 12)

                }
                else {

                    ScheduledMatTimesSection(
                        island: island,
                        day: selectedDay,
                        viewModel: viewModel,
                        matTimesForDay: $viewModel.matTimesForDay,
                        selectedDay: $viewModel.selectedDay
                    )

                }

            }
            else {

                Text("Select a day to view schedule.")
                    .font(.caption)
                    .foregroundColor(.secondary)

            }

            Spacer()

        }
        .frame(maxWidth: .infinity, alignment: .top)

        // ⭐ ADD THIS LINE
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.matTimesForDay)
    }

}


private extension ViewScheduleForIsland {

    var addScheduleButton: some View {

        Button {

            showingAddSchedule = true

        } label: {

            Label("Add Schedule", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)

    }

}

private extension ViewScheduleForIsland {

    func selectIslandAndDay(
        _ island: PirateIsland,
        _ day: DayOfWeek
    ) async -> AppDayOfWeek? {

        guard let context = island.managedObjectContext else {
            return nil
        }

        // ✅ Extract Sendable values FIRST
        let islandObjectID = island.objectID
        let dayValue = day.rawValue

        return await context.perform {

            // ✅ Re-fetch inside context safely
            guard let safeIsland =
                try? context.existingObject(with: islandObjectID)
                as? PirateIsland
            else {
                return nil
            }

            let request: NSFetchRequest<AppDayOfWeek> =
                AppDayOfWeek.fetchRequest()

            request.predicate =
                NSPredicate(
                    format: "pIsland == %@ AND day == %@",
                    safeIsland,
                    dayValue
                )

            request.fetchLimit = 1

            return try? context.fetch(request).first

        }
    }
}
