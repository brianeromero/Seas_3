//
//  AllpIslandScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/12/24.
//

import Foundation
import SwiftUI

struct AllpIslandScheduleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    var body: some View {
        VStack {
            Text("All Gyms Schedules")
                .font(.title)
                .padding()

            List {
                ForEach(sortedDays, id: \.self) { day in
                    let schedulesForDay = viewModel.matTimesForDay[day] ?? []
                    Section(header: Text(day.displayName)) {
                        ForEach(schedulesForDay.sorted {
                            guard let time1 = DateFormat.time.date(from: $0.time ?? ""),
                                  let time2 = DateFormat.time.date(from: $1.time ?? "") else {
                                return false
                            }
                            return time1 < time2
                        }, id: \.self) { matTime in
                            ScheduleRow(matTime: matTime)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadAllSchedules()
        }
    }

    var sortedDays: [DayOfWeek] {
        return viewModel.schedules.keys.sorted { $0.rawValue < $1.rawValue }
    }
}

// Closing bracket for the `AllpIslandScheduleView` struct

struct AllpIslandScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext

        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Sample Island"

        let mockAppDayOfWeek = AppDayOfWeek(context: context)
        mockAppDayOfWeek.day = DayOfWeek.monday.rawValue
        mockAppDayOfWeek.pIsland = mockIsland
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        
        let mockMatTime1 = MatTime(context: context)
        mockMatTime1.time = DateFormat.time.string(from: Date().addingTimeInterval(-3600))
        mockAppDayOfWeek.addToMatTimes(mockMatTime1)

        let mockMatTime2 = MatTime(context: context)
        mockMatTime2.time = DateFormat.time.string(from: Date().addingTimeInterval(3600))
        mockAppDayOfWeek.addToMatTimes(mockMatTime2)

        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: AppDayOfWeekRepository(persistenceController: persistenceController)
        )

        return AllpIslandScheduleView(viewModel: viewModel)
            .environment(\.managedObjectContext, context)
    }
}
