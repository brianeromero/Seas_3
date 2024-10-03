//
//  AppDayOfWeek+Extensions.swift
//  Seas_3
//
//  Created by Brian Romero on 6/29/24.
//

import Foundation
import SwiftUI

extension AppDayOfWeek {
    func isSelected(for day: DayOfWeek) -> Bool {
        guard let dayString = self.day else { return false }
        return dayString == day.displayName
    }
    
    func setSelected(day: DayOfWeek, selected: Bool) {
        self.day = selected ? day.displayName : nil
    }

    // Convert AppDayOfWeek to DayOfWeek
    var dayOfWeek: DayOfWeek? {
        guard let dayString = day else { return nil }
        return DayOfWeek(rawValue: dayString.lowercased())
    }
    
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // Safely format the timestamp for optional Date
    private func formattedCreatedTimestamp() -> String {
        // Safely unwrap the optional date
        guard let createdTimestamp = createdTimestamp else {
            return "No timestamp set" // Return a default string if nil
        }
        return Self.timestampFormatter.string(from: createdTimestamp)
    }

    // Safely unwrap properties in the description
    override public var description: String {
        let dayString = day ?? "No day set"
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
