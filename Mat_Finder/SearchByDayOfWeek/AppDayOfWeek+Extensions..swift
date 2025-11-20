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
    
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // Safely format the timestamp for optional Date
    private func formattedCreatedTimestamp() -> String {
        guard let createdTimestamp = createdTimestamp else {
            return "No timestamp set"
        }
        return Self.timestampFormatter.string(from: createdTimestamp)
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
            .sorted { ($0.time ?? "") < ($1.time ?? "") } ?? []
    }
    
    /// True when this AppDayOfWeek actually has mat times
    var hasMatTimes: Bool {
        !matTimesArray.isEmpty
    }
}
