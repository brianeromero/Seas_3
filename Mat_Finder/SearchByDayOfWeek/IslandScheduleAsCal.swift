//
//  IslandScheduleAsCal.swift
//  Mat_Finder
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
                            ForEach(viewModel.appDayOfWeekList, id: \.objectID) { appDayOfWeek in
                                if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
                                    ForEach(Array(matTimes), id: \.objectID) { matTime in
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
                    Text("No gym selected.")
                        .foregroundColor(.red)
                }
            }
            .navigationBarTitle("Mat Schedule", displayMode: .inline)
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
            Text(day.ultraShortDisplayName)
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
            ForEach(viewModel.appDayOfWeekList, id: \.objectID) { appDayOfWeek in
                if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
                    ForEach(Array(matTimes), id: \.objectID) { matTime in
                        MatTimeRow(matTime: matTime)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }

    private func filteredEvents(for hour: String) -> [AppDayOfWeek] {
        viewModel.appDayOfWeekList.filter { $0.matTimes?.contains { ($0 as? MatTime)?.time == hour } == true && $0.pIsland == island }
    }
}

struct MatTimeRow: View {

    var matTime: MatTime

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(displayTime)
                .font(.headline)

            HStack(spacing: 6) {

                ForEach(matTime.badges) { badge in
                    Text(badge.text)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(badge.color))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            if matTime.goodForBeginners {
                Text("Good for Beginners")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            if matTime.restrictions {
                Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var displayTime: String {

        guard let time = matTime.time,
              let date = AppDateFormatter.stringToDate(time) else {
            return matTime.time ?? ""
        }

        return AppDateFormatter.twelveHour.string(from: date)
    }
}

private func displayTime(for matTime: MatTime) -> String {

    guard let time = matTime.time,
          let date = AppDateFormatter.stringToDate(time) else {
        return matTime.time ?? ""
    }

    return AppDateFormatter.twelveHour.string(from: date)
}

private func scheduleView(for schedule: AppDayOfWeek) -> some View {

    let matTimes = (schedule.matTimes?.allObjects as? [MatTime] ?? [])
        .sorted(by: MatTime.scheduleSort)

    return VStack(alignment: .leading, spacing: 8) {

        Text(schedule.day)
            .font(.subheadline)
            .foregroundColor(.primary)

        ForEach(matTimes, id: \.objectID) { matTime in

            VStack(alignment: .leading, spacing: 6) {

                HStack {

                    Text("Time: \(displayTime(for: matTime))")
                        .font(.subheadline)

                    Spacer()

                    if matTime.goodForBeginners {
                        Text("Beginner")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 6) {

                    ForEach(matTime.badges) { badge in
                        Text(badge.text)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(badge.color))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
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
    }
}




struct EventView: View {
    let event: AppDayOfWeek

    var body: some View {
        scheduleView(for: event)
    }
}
