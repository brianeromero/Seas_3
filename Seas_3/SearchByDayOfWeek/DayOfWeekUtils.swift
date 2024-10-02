//
//  DayOfWeekUtils.swift
//  Seas_3
//
//  Created by Brian Romero on 6/28/24.
//

import Foundation
import SwiftUI

enum DayOfWeek: String, CaseIterable, Hashable, Identifiable, Comparable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    var id: String { rawValue } // Conforms to Identifiable

    var displayName: String {
        rawValue.capitalized // Dynamically capitalize the raw value
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
        DayOfWeek.allCases.first { $0.displayName == displayName }
    }
    
    static let twelveHourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let twentyFourHourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func formatTime(from twentyFourHourTime: String) -> String {
        guard let date = twentyFourHourFormatter.date(from: twentyFourHourTime) else {
            return twentyFourHourTime
        }
        return twelveHourFormatter.string(from: date)
    }
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
                            viewModel.updateSchedules()
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
            if let island = viewModel.selectedIsland {
                let defaultDay: DayOfWeek = .monday
                _ = viewModel.fetchCurrentDayOfWeek(for: island, day: defaultDay, selectedDayBinding: Binding(get: { viewModel.selectedDay }, set: { viewModel.selectedDay = $0 }))
            } else {
                print("No gym selected")
            }
        }
    }
}

struct DayOfWeekView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Gym"

        let mockRepository = AppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: mockRepository, context: context)

        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: mockRepository,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )

        return DayOfWeekView(viewModel: viewModel, selectedAppDayOfWeek: .constant(nil))
            .environment(\.managedObjectContext, context)
    }
}

import SwiftUI

struct DaysOfWeekView: View {
    @State private var selectedDay: DayOfWeek?

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Select a day to find Open Mats held on a specific day of the week")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)

                List {
                    ForEach(DayOfWeek.allCases) { day in
                        NavigationLink(
                            destination: DayDetailView(day: day),
                            tag: day,
                            selection: $selectedDay
                        ) {
                            Text(day.displayName)
                                .padding(.leading, 10)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                if let selectedDay = selectedDay {
                    DayDetailView(day: selectedDay)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal)
            .navigationTitle("By Days of the Week")
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

struct DaysOfWeekView_Previews: PreviewProvider {
    static var previews: some View {
        DaysOfWeekView()
    }
}

// DayPickerView.swift
import SwiftUI

struct DayPickerView: View {
    @Binding var selectedDay: DayOfWeek?

    var body: some View {
        VStack(alignment: .leading) {  // Use VStack to arrange elements vertically
            Text("Day of the Week")
                .font(.headline)
                .padding(.leading, 16)

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
        .padding() // Add padding to the entire VStack if needed
    }

}

struct DayPickerView_Previews: PreviewProvider {
    static var previews: some View {
        DayPickerView(selectedDay: .constant(.monday))
    }
}
