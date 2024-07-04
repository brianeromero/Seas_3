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
            if let matTime = schedule.matTime {
                Text(matTime)
                    .font(.headline)
            } else {
                Text("No time set")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            Text("Gi: \(schedule.gi ? "T" : "F"), NoGi: \(schedule.noGi ? "T" : "F"), Open Mat: \(schedule.openMat ? "T" : "F")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if schedule.restrictions {
                if let restrictionDescription = schedule.restrictionDescription {
                    Text("Restrictions: \(restrictionDescription)")
                        .font(.subheadline)
                        .foregroundColor(.red)
                } else {
                    Text("Restrictions: Not specified")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8.0)
        .shadow(radius: 1)
    }
}

struct ClassScheduleRow_Previews: PreviewProvider {
    static var previews: some View {
        // Create an NSManagedObjectContext for preview
        let context = PersistenceController.preview.container.viewContext
        
        // Create a preview instance of AppDayOfWeek
        let previewSchedule = AppDayOfWeek(context: context)
        previewSchedule.matTime = "10:00 AM"
        previewSchedule.gi = true
        previewSchedule.noGi = false
        previewSchedule.openMat = true
        previewSchedule.restrictions = true
        previewSchedule.restrictionDescription = "No kids allowed"
        
        // Create another preview instance without restrictions
        let previewScheduleWithoutRestrictions = AppDayOfWeek(context: context)
        previewScheduleWithoutRestrictions.matTime = "2:00 PM"
        previewScheduleWithoutRestrictions.gi = false
        previewScheduleWithoutRestrictions.noGi = true
        previewScheduleWithoutRestrictions.openMat = false
        previewScheduleWithoutRestrictions.restrictions = false
        
        return Group {
            ClassScheduleRow(schedule: previewSchedule)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("With Restrictions")
            
            ClassScheduleRow(schedule: previewScheduleWithoutRestrictions)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Without Restrictions")
        }
    }
}
