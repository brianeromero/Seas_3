//
//  AppDayOfWeekRepository.swift
//  Seas_3
//
//  Created by Brian Romero on 6/25/24.
//

import Foundation
import CoreData

class AppDayOfWeekRepository {
    static let shared = AppDayOfWeekRepository()
    
    let persistence: PersistenceController

    private init() {
        self.persistence = PersistenceController.shared
    }
    
    func saveContext() {
        persistence.saveContext()
    }
    
    // Fetch all AppDayOfWeeks
    func fetchAllAppDayOfWeeks() -> [AppDayOfWeek] {
        return persistence.fetchAllAppDayOfWeeks()
    }
    
    // Fetch specific AppDayOfWeek for a given island and day
    func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        return persistence.fetchAppDayOfWeek(for: island, day: day)
    }
    
    // Fetch or create AppDayOfWeek for a given island and day
    func fetchOrCreateAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek {
        return persistence.fetchOrCreateAppDayOfWeek(for: island, day: day)
    }
    
    // Delete schedules at specified offsets for a given day and island
    func deleteSchedule(at offsets: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        persistence.deleteSchedule(at: offsets, for: day, island: island)
    }
    
    // Fetch schedules for a specific pirate island
    func fetchSchedules(for island: PirateIsland) -> [AppDayOfWeek] {
        return persistence.fetchSchedules(for: island)
    }
}

