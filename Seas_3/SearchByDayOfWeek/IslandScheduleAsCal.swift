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
                                DayColumn(day: day, selectedDay: $selectedDay, hours: hours, viewModel: viewModel)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("No island selected.")
                        .foregroundColor(.red)
                }
            }
            .navigationBarTitle("Island Schedule", displayMode: .inline)
            .onAppear {
                viewModel.fetchCurrentDayOfWeek()
            }
        }
    }
}

struct DayColumn: View {
    let day: DayOfWeek
    @Binding var selectedDay: DayOfWeek?
    let hours: [String]
    let viewModel: AppDayOfWeekViewModel

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
                    HourRow(day: day, hour: hour, viewModel: viewModel)
                }
            }
            .padding(.vertical)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct HourRow: View {
    let day: DayOfWeek
    let hour: String
    let viewModel: AppDayOfWeekViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.appDayOfWeekList.filter { event in
                // Ensure matTime and hour are formatted and compared correctly
                if let eventTime = event.matTime, let eventDate = DateFormatter.hourFormat.date(from: eventTime), let selectedDate = DateFormatter.hourFormat.date(from: hour) {
                    return Calendar.current.isDate(eventDate, equalTo: selectedDate, toGranularity: .minute)
                }
                return false
            }) { event in
                EventView(event: event)
            }
        }
        .padding(.vertical)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

extension DateFormatter {
    static let hourFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()
}


struct EventView: View {
    let event: AppDayOfWeek

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.matTime ?? "")
                .font(.caption)
                .foregroundColor(.gray)
            Text(event.name ?? "Event Name") // Displaying event name here
                .font(.body)
                .foregroundColor(.primary)
            // Additional event details if needed
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

import SwiftUI
import CoreData

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
