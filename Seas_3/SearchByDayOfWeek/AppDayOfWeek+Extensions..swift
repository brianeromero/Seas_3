//
//  AppDayOfWeek+Extensions.swift
//  Seas_3
//
//  Created by Brian Romero on 6/29/24.
//

import Foundation

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
}

extension AppDayOfWeek {
    override public var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let createdTimestampString = formatter.string(from: createdTimestamp)
        return "AppDayOfWeek: day: \(day ?? ""), pIsland: \(pIsland?.islandName ?? ""), name: \(name ?? ""), appDayOfWeekID: \(appDayOfWeekID ?? ""), matTimes: \(matTimes?.count ?? 0), createdTimestamp: \(createdTimestampString)"
    }
}
