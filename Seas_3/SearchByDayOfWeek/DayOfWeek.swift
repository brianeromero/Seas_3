//
//  DayOfWeek.swift
//  Seas_3
//
//  Created by Brian Romero on 6/28/24.
//

import Foundation
import SwiftUI

import Foundation

enum DayOfWeek: String, CaseIterable, Hashable, Identifiable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    var id: String { self.rawValue }

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

    // Added number property
    var number: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static func from(displayName: String) -> DayOfWeek? {
        return DayOfWeek.allCases.first { $0.displayName == displayName }
    }
}


// Example usage within a function or computed property:
func exampleUsage() {
    let currentDayOfWeek = DayOfWeek.monday
    print("Today is \(currentDayOfWeek.displayName)") // Prints: "Today is Monday"
    
    if let day = DayOfWeek.from(displayName: "Tuesday") {
        print("Found day: \(day)") // Prints: "Found day: tuesday"
    }
}
