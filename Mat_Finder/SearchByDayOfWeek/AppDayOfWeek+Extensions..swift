//
//  AppDayOfWeek+Extensions.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/29/24.
//

import Foundation
import SwiftUI
import CoreData


extension AppDayOfWeek {
    func isSelected(for day: DayOfWeek) -> Bool {
        return self.day == day.displayName
    }
    
    func setSelected(day: DayOfWeek, selected: Bool) {
        self.day = selected ? day.displayName : ""
    }

    // Convert AppDayOfWeek to DayOfWeek
    var dayOfWeek: DayOfWeek? {
        return DayOfWeek(rawValue: self.day.lowercased())
    }
    

    // Safely format the timestamp for optional Date
    private func formattedCreatedTimestamp() -> String {
        guard let createdTimestamp = createdTimestamp else {
            return "No timestamp set"
        }
        return AppDateFormatter.timestamp.string(from: createdTimestamp)
    }


    // Safely unwrap properties in the description
    override public var description: String {
        let dayString = day
        let islandName = pIsland?.islandName ?? "No island set"
        let nameString = name ?? "No name set"
        let appDayOfWeekIDString = appDayOfWeekID ?? "No ID set"
        let matTimesCount = matTimes?.count ?? 0
        let createdTimestampString = formattedCreatedTimestamp() // Handle optional timestamps

        return """
        AppDayOfWeek:
        day: \(dayString),
        pIsland: \(islandName),
        name: \(nameString),
        appDayOfWeekID: \(appDayOfWeekIDString),
        matTimes: \(matTimesCount),
        createdTimestamp: \(createdTimestampString)
        """
    }
}

extension AppDayOfWeek {
    /// Returns the mat times sorted by time string
    var matTimesArray: [MatTime] {
        (matTimes as? Set<MatTime>)?
            .sorted { lhs, rhs in
                let t0Date = lhs.time.flatMap { AppDateFormatter.twelveHour.date(from: $0) }
                let t1Date = rhs.time.flatMap { AppDateFormatter.twelveHour.date(from: $0) }

                switch (t0Date, t1Date) {
                case let (d0?, d1?):
                    return d0 < d1
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return (lhs.time ?? "") < (rhs.time ?? "")
                }
            } ?? []
    }

    /// True when this AppDayOfWeek actually has mat times
    var hasMatTimes: Bool {
        !matTimesArray.isEmpty
    }
}
