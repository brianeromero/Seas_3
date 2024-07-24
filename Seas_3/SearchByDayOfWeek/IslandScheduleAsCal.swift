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
    let persistenceController = PersistenceController.shared

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

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(hours, id: \.self) { hour in
                                HourRow(hour: hour, viewModel: viewModel, island: pIsland)
                            }
                            ForEach(viewModel.appDayOfWeekList, id: \.self) { appDayOfWeek in
                                if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
                                    ForEach(Array(matTimes), id: \.self) { matTime in
                                        MatTimeRow(matTime: matTime)
                                    }
                                }
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
        }
    }
}

struct MatTimeRow: View {
    let matTime: MatTime

    var body: some View {
        HStack {
            Text(matTime.time ?? "Unknown time")
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(matTime.type ?? "Unknown type")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
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
            
            // New section to display MatTime entities
            Text("Mat Times")
                .font(.headline)
                .bold()
                .padding(.bottom)
            ForEach(viewModel.appDayOfWeekList, id: \.self) { appDayOfWeek in
                if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
                    ForEach(Array(matTimes), id: \.id) { matTime in
                        MatTimeRow(matTime: matTime)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }

    private func filteredEvents(for hour: String) -> [AppDayOfWeek] {
        viewModel.appDayOfWeekList.filter { $0.matTimes?.contains { ($0 as? MatTime)?.time == hour } == true && $0.pIsland == island }
    }
}


private func scheduleView(for schedule: AppDayOfWeek) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text(schedule.day ?? "Unknown day")
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            // Add any other properties from AppDayOfWeek if needed
        }

        // Iterate over MatTime objects associated with the schedule
        if let matTimes = schedule.matTimes as? Set<MatTime> {
            ForEach(Array(matTimes), id: \.id) { matTime in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Time: \(matTime.time ?? "Unknown time")")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(matTime.type ?? "Unknown type")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
        } else {
            Text("No MatTimes available")
                .font(.body)
                .foregroundColor(.gray)
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
        return IslandScheduleAsCal(viewModel: viewModel, pIsland: mockIsland)
            .environment(\.managedObjectContext, context)
    }
}
