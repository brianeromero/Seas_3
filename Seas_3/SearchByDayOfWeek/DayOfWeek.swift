//
//  DayOfWeek.swift
//  Seas_3
//
//  Created by Brian Romero on 6/28/24.
//

import Foundation

enum DayOfWeek: Int16, CaseIterable, Identifiable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    
    var id: Int16 { self.rawValue }
    
    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}
