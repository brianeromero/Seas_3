//
//  IslandScheduleView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/8/24.
//

import SwiftUI
import CoreData

struct IslandScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    var pIsland: PirateIsland?

    @State private var selectedDay: DayOfWeek?
    @State private var selectedMatTime: MatTime?
    @StateObject private var enterZipCodeViewModel: EnterZipCodeViewModel

    init(viewModel: AppDayOfWeekViewModel, pIsland: PirateIsland?) {
        self.viewModel = viewModel
        self.pIsland = pIsland
        _enterZipCodeViewModel = StateObject(wrappedValue: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: PersistenceController.shared
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let islandName = pIsland?.islandName {
                        Text("Schedule for \(islandName)")
                            .font(.headline)
                            .padding(.bottom)

                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            let schedules = viewModel.appDayOfWeekList.filter { $0.day == day.displayName }
                            if !schedules.isEmpty {
                                DisclosureGroup(
                                    content: {
                                        ForEach(schedules, id: \.self) { schedule in
                                            scheduleView(for: schedule)
                                                .onTapGesture {
                                                    selectedDay = day
                                                    selectedMatTime = (schedule.matTimes?.allObjects.first as? MatTime)
                                                }
                                        }
                                    },
                                    label: {
                                        Text(day.ultraShortDisplayName)
                                            .font(.subheadline)
                                            .padding(.top)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        Text("No gym selected.")
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationBarTitle("Mat Schedule", displayMode: .inline)
            .sheet(item: $selectedDay) { day in
                ScheduleDetailModal(
                    viewModel: AppDayOfWeekViewModel(
                        selectedIsland: pIsland,
                        repository: AppDayOfWeekRepository.shared,
                        enterZipCodeViewModel: enterZipCodeViewModel
                    ),
                    day: day
                )
            }
        }
        .onAppear {
            if let pIsland = pIsland {
                // Use a default or previously selected day here
                let dayToFetch: DayOfWeek = selectedDay ?? .monday
                
                Task {
                    _ = await viewModel.fetchCurrentDayOfWeek(
                        for: pIsland,
                        day: dayToFetch,
                        selectedDayBinding: Binding(
                            get: { viewModel.selectedDay },
                            set: { viewModel.selectedDay = $0 }
                        )
                    )
                }
            }
        }
    }

    private func scheduleView(for schedule: AppDayOfWeek) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(schedule.matTimes?.allObjects as? [MatTime] ?? [], id: \.self) { matTime in
                HStack {
                    Text(matTime.time ?? "Unknown time")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(matTime.goodForBeginners ? "Beginners" : "")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                HStack {
                    Label("Gi", systemImage: matTime.gi ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(matTime.gi ? .green : .red)
                    Label("NoGi", systemImage: matTime.noGi ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(matTime.noGi ? .green : .red)
                    Label("Open Mat", systemImage: matTime.openMat ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(matTime.openMat ? .green : .red)
                }
                if matTime.restrictions {
                    Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}
