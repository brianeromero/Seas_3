//  DayOfWeekUtils.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/28/24.
//

import Foundation
import SwiftUI



enum DayOfWeek: String, CaseIterable, Hashable, Identifiable, Comparable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var number: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static func < (lhs: DayOfWeek, rhs: DayOfWeek) -> Bool {
        lhs.number < rhs.number
    }

    static func from(displayName: String) -> DayOfWeek? {
        print("Attempting to create DayOfWeek from displayName: \(displayName)")
        guard let day = DayOfWeek.allCases.first(where: { $0.displayName == displayName }) else {
            print("Error: Invalid displayName: \(displayName)")
            return nil
        }
        print("Created DayOfWeek: \(day)")
        return day
    }

    /// Converts 24-hour time string to 12-hour time string
    static func formatTime(from twentyFourHourTime: String) -> String {
        guard let date = AppDateFormatter.twentyFourHour.date(from: twentyFourHourTime) else {
            return twentyFourHourTime
        }
        return AppDateFormatter.twelveHour.string(from: date)
    }
}

enum DayOfWeekError: Error {
    case invalidDayValue
}


// DayOfWeekView.swift

import SwiftUI

struct DayOfWeekView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?

    var body: some View {
        NavigationView {
            DayOfWeekSettings(viewModel: viewModel)
                .navigationTitle("Day of Week Settings")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            Task {
                                await viewModel.updateSchedules()
                            }
                        }
                    }
                }
        }
    }
}

struct DayOfWeekSettings: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    var body: some View {
        VStack {
            ForEach(DayOfWeek.allCases, id: \.self) { day in
                Toggle(day.displayName, isOn: viewModel.binding(for: day))
                    .padding()
            }
        }
        .onAppear {
            print("DayOfWeekSettings appeared")
            if let island = viewModel.selectedIsland {
                print("Selected island: \(island.islandName ?? "")")
                let defaultDay: DayOfWeek = .monday
                print("Fetching current day of week for island: \(island.islandName ?? "") and day: \(defaultDay.displayName)")
                Task {
                    _ = await viewModel.fetchCurrentDayOfWeek(for: island, day: defaultDay, selectedDayBinding: Binding(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 }))
                }
            } else {
                print("No island selected")
            }
        }
    }
}



// DaysOfWeekView.swift

import SwiftUI

struct DaysOfWeekView: View {
    @State private var selectedDay: DayOfWeek?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Select a day...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)

                List(DayOfWeek.allCases, id: \.self) { day in
                    NavigationLink(value: day) {
                        Text(day.displayName)
                            .padding(.leading, 10)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("By Days of the Week")
            .navigationDestination(for: DayOfWeek.self) { day in
                DayDetailView(day: day)
            }
        }
    }
}


struct DayDetailView: View {
    let day: DayOfWeek

    var body: some View {
        Text("Detail view for \(day.displayName)")
            .font(.title)
            .padding()
            .onAppear {
                print("Rendering detail view for \(day.displayName)")
            }
    }
}



// DayPickerView.swift

import SwiftUI


struct DayPickerView: View {
    @Binding var selectedDay: DayOfWeek?

    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        Button(action: {
                            selectedDay = day
                        }) {
                            HStack {
                                Text(day.displayName)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                if selectedDay == day {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .background(Color.blue.opacity(selectedDay == day ? 0.2 : 0))
                            .cornerRadius(16)
                        }
                    }
                }
                .padding(.trailing, 16)
            }
        }
        .padding()
        // MARK: Navigation bar styling to match "Gyms Near Me"
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Day of the Week")
                    .font(.title) // same size as "Gyms Near Me"
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }
}
