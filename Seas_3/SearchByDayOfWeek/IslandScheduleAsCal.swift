//
//  IslandScheduleAsCal.swift
//  Seas_3
//
//  Created by Brian Romero on 7/8/24.
//

import SwiftUI

struct IslandScheduleAsCal: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    var pIsland: PirateIsland?
    
    @State private var appDayOfWeeks: [AppDayOfWeek] = []
    let repository = AppDayOfWeekRepository.shared

    @State private var selectedDay: DayOfWeek?

    private let hours: [String] = (5...21).map { String(format: "%02d:00", $0) }

    var body: some View {
        NavigationView {
            VStack {
                if let islandName = pIsland?.islandName {
                    Text("Schedule for \(islandName)")
                        .font(.largeTitle)
                        .bold()
                        .padding(.bottom)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(DayOfWeek.allCases, id: \.self) { day in
                                DayColumn(day: day, selectedDay: $selectedDay, hours: hours, viewModel: viewModel, island: pIsland)
                            }
                        }
                        .padding(.horizontal)
                    }

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(hours, id: \.self) { hour in
                                HourRow(hour: hour, viewModel: viewModel, island: pIsland)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                } else {
                    Text("No island selected.")
                        .foregroundColor(.red)
                }
            }
            .navigationBarTitle("Island Schedule", displayMode: .inline)
            .onAppear {
                if let island = pIsland {
                    appDayOfWeeks = repository.fetchAppDayOfWeeks(for: island)
                    viewModel.appDayOfWeekList = appDayOfWeeks
                }
            }
        }
    }
}

struct DayColumn: View {
    let day: DayOfWeek
    @Binding var selectedDay: DayOfWeek?
    let hours: [String]
    let viewModel: AppDayOfWeekViewModel
    let island: PirateIsland?

    var body: some View {
        VStack {
            Text(day.displayName)
                .font(.headline)
                .bold()
                .padding(.vertical, 8)
                .background(day == selectedDay ? Color.yellow : Color.clear)
                .cornerRadius(8)
                .onTapGesture {
                    selectedDay = day
                }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(hours, id: \.self) { hour in
                    HourRow(hour: hour, viewModel: viewModel, island: island)
                }
            }
            .padding(.vertical)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct HourRow: View {
    let hour: String
    let viewModel: AppDayOfWeekViewModel
    let island: PirateIsland?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hour)
                .font(.caption)
                .foregroundColor(.gray)
            
            ForEach(filteredEvents(for: hour), id: \.self) { event in
                scheduleView(for: event)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }

    private func filteredEvents(for hour: String) -> [AppDayOfWeek] {
        viewModel.appDayOfWeekList.filter { $0.matTime == hour && $0.pIsland == island }
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

struct EventView: View {
    let event: AppDayOfWeek

    var body: some View {
        scheduleView(for: event)
    }
}

struct IslandScheduleAsCal_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        // Mock data for different days and hours
        for day in DayOfWeek.allCases {
            for hour in (5...21).map({ String(format: "%02d:00", $0) }) {
                let mockSchedule = AppDayOfWeek(context: context)
                mockSchedule.day = day.displayName
                mockSchedule.matTime = hour
                mockSchedule.gi = Bool.random()
                mockSchedule.noGi = Bool.random()
                mockSchedule.openMat = true
                mockSchedule.restrictions = false
                mockSchedule.restrictionDescription = nil
                mockSchedule.goodForBeginners = true
                viewModel.appDayOfWeekList.append(mockSchedule)
            }
        }

        return NavigationView {
            IslandScheduleAsCal(viewModel: viewModel, pIsland: mockIsland)
                .environment(\.managedObjectContext, context)
        }
    }
}
