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
            // Access the matTimes relationship and display the corresponding MatTime objects
            if let matTimes = schedule.matTimes {
                let matTimeArray = matTimes.compactMap { $0 as? MatTime }
                
                ForEach(matTimeArray, id: \.id) { matTime in
                    VStack(alignment: .leading) {
                        Text("Time: \(matTime.time ?? "No time set")")
                            .font(.body)
                        Text("Gi: \(matTime.gi ? "Yes" : "No")")
                            .font(.caption)
                        Text("NoGi: \(matTime.noGi ? "Yes" : "No")")
                            .font(.caption)
                        Text("Open Mat: \(matTime.openMat ? "Yes" : "No")")
                            .font(.caption)
                        Text("Restrictions: \(matTime.restrictions ? "Yes" : "No")")
                            .font(.caption)
                        if let restrictionDesc = matTime.restrictionDescription, !restrictionDesc.isEmpty {
                            Text("Restriction Description: \(restrictionDesc)")
                                .font(.caption)
                        }
                        Text("Good for Beginners: \(matTime.goodForBeginners ? "Yes" : "No")")
                            .font(.caption)
                        Text("Adult: \(matTime.adult ? "Yes" : "No")")
                            .font(.caption)
                    }
                }
            } else {
                Text("No MatTimes available")
                    .font(.body)
                    .foregroundColor(.gray)
            }

            // Display the name, if available
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
        mondaySchedule1.name = "Sample Class"
        mondaySchedule1.pIsland = island
        
        // Create a new MatTime object and add it to the matTimes relationship
        let matTime1 = MatTime(context: context)
        matTime1.time = "10:00 AM"
        matTime1.gi = true
        matTime1.noGi = false
        matTime1.openMat = true
        matTime1.restrictions = false
        matTime1.restrictionDescription = nil
        matTime1.goodForBeginners = true
        matTime1.adult = false
        mondaySchedule1.addToMatTimes(matTime1)
        
        let mondaySchedule2 = AppDayOfWeek(context: context)
        mondaySchedule2.day = "Monday"
        mondaySchedule2.name = "Sample Class 2"
        mondaySchedule2.pIsland = island
        
        // Create another MatTime object and add it to the matTimes relationship
        let matTime2 = MatTime(context: context)
        matTime2.time = "05:00 PM"
        matTime2.gi = false
        matTime2.noGi = true
        matTime2.openMat = false
        matTime2.restrictions = true
        matTime2.restrictionDescription = "Beginners only"
        matTime2.goodForBeginners = false
        matTime2.adult = true
        mondaySchedule2.addToMatTimes(matTime2)
        
        return pIslandScheduleListView(day: .monday, schedules: [mondaySchedule1, mondaySchedule2])
            .padding()
            .previewLayout(.sizeThatFits)
            .environment(\.managedObjectContext, context)
    }
}
#endif
