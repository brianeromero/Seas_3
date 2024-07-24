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
}
