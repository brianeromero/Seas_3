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
                if let pIsland = pIsland {
                    viewModel.fetchCurrentDayOfWeek(for: pIsland)
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

struct IslandScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        for day in DayOfWeek.allCases {
            let mockSchedule = AppDayOfWeek(context: context)
            let mockMatTime1 = MatTime(context: context)
            mockMatTime1.time = "10:00 AM"
            mockMatTime1.gi = true
            mockMatTime1.noGi = false
            mockMatTime1.openMat = true
            mockMatTime1.restrictions = false
            mockMatTime1.restrictionDescription = nil
            mockMatTime1.goodForBeginners = true
            mockMatTime1.adult = false
            mockSchedule.day = day.displayName
            mockSchedule.matTimes = [mockMatTime1] as NSSet
            viewModel.appDayOfWeekList.append(mockSchedule)
        }

        return NavigationView {
            IslandScheduleView(viewModel: viewModel, pIsland: mockIsland)
                .environment(\.managedObjectContext, context)
        }
    }
}
