//
//  ScheduledMatTimesSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/26/24.
//

import Foundation
import SwiftUI

struct ScheduledMatTimesSection: View {
    let island: PirateIsland
    let day: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var matTimesForDay: [DayOfWeek: [MatTime]]
    @Binding var selectedDay: DayOfWeek?



    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            if let appDayOfWeek = island.daysOfWeekArray.first(where: { $0.day == day.rawValue }),
               let day = appDayOfWeek.day {
                MatTimesList(day: day, matTimes: viewModel.fetchMatTimes(for: self.day))
            } else {
                Text("No mat times available for \(self.day.rawValue) at \(island.islandName ??  "this island").")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            debugPrintMatTimesForDay()
        }
    }

    struct MatTimesList: View {
        let day: String
        let matTimes: [MatTime]

        var body: some View {
            List {
                ForEach(matTimes) { matTime in
                    VStack(alignment: .leading) {
                        Text("Time: \(formatTime(matTime.time ?? "Unknown"))")
                            .font(.headline)
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
                        if matTime.goodForBeginners {
                            Text("Good for Beginners")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        if matTime.kids {
                            Text("Kids")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
            }
        }
        
        // Helper function for formatting time
        private func formatTime(_ time: String) -> String {
            if let date = DateFormat.time.date(from: time) {
                return DateFormat.shortTime.string(from: date)
            } else {
                return time
            }
        }
    }

    // Debug function
    func debugPrintMatTimesForDay() {
        debugPrint("matTimesForDay in ScheduledMatTimesSection:", matTimesForDay)
    }
}

struct ScheduledMatTimesSection_Previews: PreviewProvider {
    static var previews: some View {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

        // Create a mock PirateIsland
        let pirateIsland = PirateIsland(context: context)
        pirateIsland.islandName = "Mock Island"
        pirateIsland.latitude = 37.7749
        pirateIsland.longitude = -122.4194

        // Create a mock AppDayOfWeekRepository
        let repository = AppDayOfWeekRepository.shared

        // Create a mock EnterZipCodeViewModel
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: repository, context: context)

        // Create a mock AppDayOfWeekViewModel
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: pirateIsland,
            repository: repository,
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )

        // Create a mock DayOfWeek
        let day: DayOfWeek = .monday

        // Create a dictionary for matTimesForDay
        let matTimesForDay: [DayOfWeek: [MatTime]] = [.monday: []]

        return ScheduledMatTimesSection(
            island: pirateIsland,
            day: day,
            viewModel: viewModel,
            matTimesForDay: .constant(matTimesForDay),
            selectedDay: .constant(day)
        )
        .environment(\.managedObjectContext, context)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
