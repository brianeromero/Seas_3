//
//  AppDayOfWeek+Extensions..swift
//  Seas_3
//
//  Created by Brian Romero on 6/29/24.
//

import Foundation

extension AppDayOfWeek {
    func isSelected(for day: DayOfWeek) -> Bool {
        switch day {
        case .sunday: return self.sunday
        case .monday: return self.monday
        case .tuesday: return self.tuesday
        case .wednesday: return self.wednesday
        case .thursday: return self.thursday
        case .friday: return self.friday
        case .saturday: return self.saturday
        }
    }
    
    func setSelected(day: DayOfWeek, selected: Bool) {
        switch day {
        case .sunday: self.sunday = selected
        case .monday: self.monday = selected
        case .tuesday: self.tuesday = selected
        case .wednesday: self.wednesday = selected
        case .thursday: self.thursday = selected
        case .friday: self.friday = selected
        case .saturday: self.saturday = selected
        }
    }
}
