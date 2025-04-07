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
                                    ForEach(Array(matTimes), id: \.id) { matTime in
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
    }

    private func filteredEvents(for hour: String) -> [AppDayOfWeek] {
        viewModel.appDayOfWeekList.filter { $0.matTimes?.contains { ($0 as? MatTime)?.time == hour } == true && $0.pIsland == island }
    }
}

struct MatTimeRow: View {
    var matTime: MatTime

    var body: some View {
        VStack(alignment: .leading) {
            Text(matTime.time ?? "")
                .font(.headline)
            Text("Gi: \(matTime.gi ? "Yes" : "No"), No Gi: \(matTime.noGi ? "Yes" : "No"), Open Mat: \(matTime.openMat ? "Yes" : "No")")
                .font(.subheadline)
            Text("Restrictions: \(matTime.restrictions ? "Yes" : "No")")
                .font(.body)
            if matTime.goodForBeginners {
                Text("Good for Beginners")
                    .font(.body)
            }
            if matTime.kids {
                Text("Kids Class")
                    .font(.body)
            }
        }
    }
}

private func scheduleView(for schedule: AppDayOfWeek) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text(schedule.day)
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

/*
struct IslandScheduleAsCal_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        // Create a mock PirateIsland instance
        let mockIsland = PirateIsland(context: persistenceController.container.viewContext)
        mockIsland.islandID = UUID()
        mockIsland.islandName = "Mock Gym"

        // Create mock AppDayOfWeek instances
        let appDayOfWeek1 = AppDayOfWeek(context: persistenceController.container.viewContext)
        appDayOfWeek1.appDayOfWeekID = UUID().uuidString
        appDayOfWeek1.day = DayOfWeek.monday.rawValue
        appDayOfWeek1.name = "Morning Class"
        
        let appDayOfWeek2 = AppDayOfWeek(context: persistenceController.container.viewContext)
        appDayOfWeek2.appDayOfWeekID = UUID().uuidString
        appDayOfWeek2.day = DayOfWeek.tuesday.rawValue
        appDayOfWeek2.name = "Evening Class"
        
        // Create MatTime instances and associate them with AppDayOfWeek
        let matTime1 = MatTime(context: persistenceController.container.viewContext)
        matTime1.id = UUID()
        matTime1.time = "10:00"
        matTime1.gi = true
        matTime1.noGi = false
        matTime1.openMat = false
        matTime1.restrictions = false
        matTime1.restrictionDescription = nil
        matTime1.goodForBeginners = true
        matTime1.kids = false

        let matTime2 = MatTime(context: persistenceController.container.viewContext)
        matTime2.id = UUID()
        matTime2.time = "18:00"
        matTime2.gi = false
        matTime2.noGi = true
        matTime2.openMat = true
        matTime2.restrictions = true
        matTime2.restrictionDescription = "Limited Space"
        matTime2.goodForBeginners = false
        matTime2.kids = true
        
        // Associate MatTime with AppDayOfWeek
        appDayOfWeek1.addToMatTimes(matTime1)
        appDayOfWeek2.addToMatTimes(matTime2)
        
        // Initialize EnterZipCodeViewModel
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: AppDayOfWeekRepository(persistenceController: persistenceController), persistenceController: persistenceController)
        
        // Initialize the view model
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: AppDayOfWeekRepository(persistenceController: persistenceController),
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        viewModel.appDayOfWeekList = [appDayOfWeek1, appDayOfWeek2]

        return IslandScheduleAsCal(viewModel: viewModel, pIsland: mockIsland)
            .previewDisplayName("Gym Schedule Preview")
    }
}
*/
