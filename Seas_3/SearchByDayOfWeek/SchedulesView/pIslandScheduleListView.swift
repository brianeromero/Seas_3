//
//  pIslandScheduleListView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/12/24.
//

import SwiftUI

struct pIslandScheduleListView: View {
    let day: DayOfWeek
    let schedules: [AppDayOfWeek]

    var body: some View {
        VStack {
            Text("Schedules for \(day.displayName)")
                .font(.title)
                .padding()

            List(schedules) { schedule in
                ScheduleRow(schedule: schedule)
            }
        }
    }
}

struct ScheduleRow: View {
    let schedule: AppDayOfWeek

    var body: some View {
        VStack(alignment: .leading) {
            Text("Time: \(schedule.matTime ?? "Not specified")")
                .font(.body)
            Text("Gi: \(schedule.gi ? "Yes" : "No")  NoGi: \(schedule.noGi ? "Yes" : "No")")
                .font(.caption)
            Text("Open Mat: \(schedule.openMat ? "Yes" : "No")")
                .font(.caption)
            Text("Restrictions: \(schedule.restrictions ? "Yes" : "No")")
                .font(.caption)
            if let restrictionDesc = schedule.restrictionDescription, !restrictionDesc.isEmpty {
                Text("Restriction Description: \(restrictionDesc)")
                    .font(.caption)
            }

            // Handling for matTime and name
            if let matTime = schedule.matTime, !matTime.isEmpty {
                Text("Mat Time: \(matTime)")
                    .font(.body)
            } else {
                Text("Mat Time: Not specified")
                    .font(.body)
                    .foregroundColor(.gray)
            }

            if let name = schedule.name, !name.isEmpty {
                Text("Name: \(name)")
                    .font(.body)
            } else {
                Text("Name: Not generated")
                    .font(.body)
                    .foregroundColor(.gray)
            }

            Divider()
        }
        .padding(.vertical, 5)
    }
}

#if DEBUG
struct pIslandScheduleListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let island = PirateIsland(context: context)
        island.islandName = "Sample Island"
        
        let mondaySchedule1 = AppDayOfWeek(context: context)
        mondaySchedule1.day = "Monday"
        mondaySchedule1.matTime = "10:00 AM"
        mondaySchedule1.gi = true
        mondaySchedule1.noGi = false
        mondaySchedule1.openMat = true
        mondaySchedule1.restrictions = false
        mondaySchedule1.restrictionDescription = nil
        mondaySchedule1.pIsland = island
        
        let mondaySchedule2 = AppDayOfWeek(context: context)
        mondaySchedule2.day = "Monday"
        mondaySchedule2.matTime = "05:00 PM"
        mondaySchedule2.gi = false
        mondaySchedule2.noGi = true
        mondaySchedule2.openMat = false
        mondaySchedule2.restrictions = true
        mondaySchedule2.restrictionDescription = "Beginners only"
        mondaySchedule2.pIsland = island
        
        return pIslandScheduleListView(day: .monday, schedules: [mondaySchedule1, mondaySchedule2])
            .padding()
            .previewLayout(.sizeThatFits)
            .environment(\.managedObjectContext, context)
    }
}
#endif
