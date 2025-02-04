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
    
    private var gi: Bool {
        schedule.matTimes?.compactMap { ($0 as? MatTime)?.gi }.contains(true) ?? false
    }
    
    private var noGi: Bool {
        schedule.matTimes?.compactMap { ($0 as? MatTime)?.noGi }.contains(true) ?? false
    }
    
    private var openMat: Bool {
        schedule.matTimes?.compactMap { ($0 as? MatTime)?.openMat }.contains(true) ?? false
    }
    
    private var restrictionDescription: String {
        let restrictions = schedule.matTimes?.compactMap { ($0 as? MatTime)?.restrictionDescription }.filter { !$0.isEmpty } ?? []
        return restrictions.isEmpty ? "Not specified" : restrictions.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let matTimes = schedule.matTimes as? Set<MatTime> {
                let matTimeArray = matTimes.sorted { ($0.time ?? "") < ($1.time ?? "") }
                ForEach(matTimeArray, id: \.id) { matTime in
                    Text(matTime.time ?? "No time set")
                        .font(.headline)
                }
            } else {
                Text("No times set")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            
            Text("Gi: \(gi ? "T" : "F"), NoGi: \(noGi ? "T" : "F"), Open Mat: \(openMat ? "T" : "F")")
                .foregroundColor(.secondary)
            
            if schedule.matTimes?.compactMap({ ($0 as? MatTime)?.restrictions }).contains(true) == true {
                Text("Restrictions: \(restrictionDescription)")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8.0)
    }
}

struct ClassScheduleRow_Previews: PreviewProvider {
    static var previews: some View {
        // Create an NSManagedObjectContext for preview
        let context = PersistenceController.preview.container.viewContext
        
        // Create a preview instance of AppDayOfWeek
        let previewSchedule = AppDayOfWeek(context: context)
        
        // Create a preview instance of MatTime
        let matTime = MatTime(context: context)
        matTime.time = "09:00 AM"
        matTime.gi = true
        matTime.noGi = false
        matTime.openMat = false
        matTime.restrictions = true
        matTime.restrictionDescription = "No kids allowed"
        matTime.goodForBeginners = false
        matTime.kids = true
        previewSchedule.addToMatTimes(matTime)
        
        // Create another preview instance without restrictions
        let previewScheduleWithoutRestrictions = AppDayOfWeek(context: context)
        previewScheduleWithoutRestrictions.addToMatTimes(matTime)
        
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
