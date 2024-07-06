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
    func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek, fetchFirstOnly: Bool = false) -> [AppDayOfWeek] {
        return persistence.fetchAppDayOfWeek(for: island, day: day, fetchFirstOnly: fetchFirstOnly)
    }
    
    // Optional: Implement fetchOrCreateAppDayOfWeek as needed
    // Example:
    func fetchOrCreateAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek {
        return persistence.fetchOrCreateAppDayOfWeek(for: island, day: day)
    }
    
    func deleteSchedule(at offsets: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        let daySchedules = persistence.fetchAppDayOfWeek(for: island, day: day)
        
        for index in offsets {
            let scheduleToDelete = daySchedules[index]
            persistence.container.viewContext.delete(scheduleToDelete)
        }
        
        persistence.saveContext()
    }
}

