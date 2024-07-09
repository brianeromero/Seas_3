//
//  IslandScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/8/24.
//

import SwiftUI

struct IslandScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    var pIsland: PirateIsland?

    @State private var selectedDay: DayOfWeek?

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
                        Text("No island selected.")
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationBarTitle("Island Schedule", displayMode: .inline)
            .sheet(item: $selectedDay) { day in
                ScheduleDetailModal(viewModel: viewModel, day: day)
            }
            .onAppear {
                viewModel.fetchCurrentDayOfWeek()
            }
        }
    }

    private func scheduleView(for schedule: AppDayOfWeek) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.matTime ?? "Unknown time")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text(schedule.goodForBeginners ? "Beginners" : "")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            HStack {
                Label("Gi", systemImage: schedule.gi ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(schedule.gi ? .green : .red)
                Label("NoGi", systemImage: schedule.noGi ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(schedule.noGi ? .green : .red)
                Label("Open Mat", systemImage: schedule.openMat ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(schedule.openMat ? .green : .red)
            }
            if schedule.restrictions {
                Text("Restrictions: \(schedule.restrictionDescription ?? "Yes")")
                    .font(.caption)
                    .foregroundColor(.red)
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
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        // Mock data for different days
        for day in DayOfWeek.allCases {
            let mockSchedule = AppDayOfWeek(context: context)
            mockSchedule.day = day.displayName
            mockSchedule.matTime = "10:00 AM"
            mockSchedule.gi = true
            mockSchedule.noGi = false
            mockSchedule.openMat = true
            mockSchedule.restrictions = false
            mockSchedule.restrictionDescription = nil
            mockSchedule.goodForBeginners = true
            viewModel.appDayOfWeekList.append(mockSchedule)
        }

        return NavigationView {
            IslandScheduleView(viewModel: viewModel, pIsland: mockIsland)
                .environment(\.managedObjectContext, context)
        }
    }
}
