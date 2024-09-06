//
//  IslandScheduleView.swift
//  Seas_3
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
            context: viewModel.viewContext
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
                                        Text(day.displayName)
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
                let dayToFetch: DayOfWeek = selectedDay ?? .monday // Default to .monday if selectedDay is nil
                viewModel.fetchCurrentDayOfWeek(for: pIsland, day: dayToFetch)
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

struct IslandScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a mock PirateIsland
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Gym"
        
        // Create a mock EnterZipCodeViewModel
        let enterZipCodeViewModel = EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            context: context
        )
        
        // Create a mock AppDayOfWeekViewModel with mock data
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: MockAppDayOfWeekRepository(persistenceController: PersistenceController.preview),
            enterZipCodeViewModel: enterZipCodeViewModel
        )
        
        // Populate viewModel with mock AppDayOfWeek data
        for day in DayOfWeek.allCases {
            let mockSchedule = AppDayOfWeek(context: context)
            let mockMatTime = MatTime(context: context)
            mockMatTime.time = "10:00 AM"
            mockMatTime.gi = true
            mockMatTime.noGi = false
            mockMatTime.openMat = true
            mockMatTime.restrictions = false
            mockMatTime.restrictionDescription = nil
            mockMatTime.goodForBeginners = true
            mockMatTime.kids = false
            mockSchedule.day = day.displayName
            mockSchedule.matTimes = [mockMatTime] as NSSet
            viewModel.appDayOfWeekList.append(mockSchedule)
        }
        
        return NavigationView {
            IslandScheduleView(viewModel: viewModel, pIsland: mockIsland)
                .environment(\.managedObjectContext, context)
        }
    }
}
