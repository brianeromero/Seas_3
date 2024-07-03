//
//  ClassScheduleRow.swift
//  Seas_3
//
//  Created by Brian Romero on 7/3/24.
//

import Foundation
import SwiftUI
import CoreData

struct ClassScheduleRow: View {
    var schedule: AppDayOfWeek
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(schedule.matTime ?? "")")
            Text("Gi: \(schedule.gi ? "T" : "F"), NoGi: \(schedule.noGi ? "T" : "F"), Open Mat: \(schedule.openMat ? "T" : "F")")
            if schedule.restrictions {
                Text("Restrictions: \(schedule.restrictionDescription ?? "")")
            }
        }
    }
}

struct ClassScheduleRow_Previews: PreviewProvider {
    static var previews: some View {
        let previewSchedule = AppDayOfWeek() // Create a preview instance of AppDayOfWeek
        previewSchedule.matTime = "10:00 AM"
        previewSchedule.gi = true
        previewSchedule.noGi = false
        previewSchedule.openMat = true
        previewSchedule.restrictions = true
        previewSchedule.restrictionDescription = "No kids allowed"

        return ClassScheduleRow(schedule: previewSchedule)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
