//
//  ViewScheduleForIsland2.swift
//  Mat_Finder
//
//  Created by Brian Romero on 8/28/24.
//

import Foundation
import SwiftUI
import CoreData


struct ViewScheduleForIsland2: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    
    @State private var showingAddSchedule = false

    @State private var selectedIslandID: String?

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var showLoginPrompt = false
    
    let island: PirateIsland

    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                daySelectorSection
            }
            .padding([.horizontal, .top])

            ScrollView {
                scheduleSection
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            addScheduleButton
        }
        .alert(alertTitle, isPresented: $showLoginPrompt) {

            Button("Login / Create Account") {
                NotificationCenter.default.post(
                    name: .navigateToLogin,
                    object: nil
                )
            }

            Button("Cancel", role: .cancel) { }

        } message: {
            Text(alertMessage)
        }
        .sheet(
            isPresented: $showingAddSchedule,
            onDismiss: {
                Task {
                    await viewModel.preloadAllSchedules(for: island)
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
            selectedIslandID = island.islandID

            viewModel.selectedDay = nil
            viewModel.matTimesForDay = [:]

            Task {
                await viewModel.preloadAllSchedules(for: island)
            }
        }
    }
    
}


private extension ViewScheduleForIsland2 {

    var headerSection: some View {

        Text(island.islandName ?? "Unknown Gym")
            .font(.title2)
            .fontWeight(.semibold)
    }

}

private extension ViewScheduleForIsland2 {

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

private extension ViewScheduleForIsland2 {

    var scheduleSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            if let selectedDay = viewModel.selectedDay {

                let matTimes = (viewModel.matTimesForDay[selectedDay] ?? [])
                    .sorted(by: MatTime.scheduleSort)

                if matTimes.isEmpty {

                    Text("""
                    No classes scheduled for \(selectedDay.displayName) at \(island.islandName ?? "").

                    Click the button below to add schedule.
                    """)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 12)

                } else {

                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(matTimes, id: \.objectID) { matTime in
                            ScheduleCard(matTime: matTime, island: island)
                        }
                    }

                    Text("Click the button below to edit or add schedule.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }

            } else {

                Text("Select a day to view scheduled classes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.8),
            value: viewModel.selectedDay
        )
    }
}

private extension ViewScheduleForIsland2 {

    var addScheduleButton: some View {

        Button {

            if authenticationState.isAuthenticated {

                showingAddSchedule = true

            } else {

                alertTitle = "Login Required"

                alertMessage = "You must be logged in to access this feature."

                showLoginPrompt = true

            }

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

private extension ViewScheduleForIsland2 {

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
