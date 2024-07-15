//
//  AppDayOfWeekRepository.swift
//  Seas_3
//
//  Created by Brian Romero on 6/25/24.
//

import Foundation
import CoreData

class AppDayOfWeekRepository {
    static let shared = AppDayOfWeekRepository(persistence: PersistenceController.shared) // Define shared instance

    let persistence: PersistenceController

    // Change the initializer access level to internal or public
    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    // Save changes to the CoreData context
    func saveContext() {
        print("AppDayOfWeekRepository - Saving context")
        persistence.saveContext()
    }

    // Fetch all AppDayOfWeek entities
    func fetchAllAppDayOfWeeks() -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching all AppDayOfWeeks")
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        do {
            return try persistence.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching AppDayOfWeeks: \(error.localizedDescription)")
            return []
        }
    }


    // Fetch specific AppDayOfWeek for a given island and day
    func fetchAppDayOfWeekFromPersistence(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        return persistence.fetchAppDayOfWeekForIslandAndDay(for: island, day: day)
    }
    

    // Fetch or create AppDayOfWeek for a given island and day
    func fetchOrCreateAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            if let existingDay = try persistence.container.viewContext.fetch(fetchRequest).first {
                return existingDay
            } else {
                let newDay = AppDayOfWeek(context: persistence.container.viewContext)
                newDay.pIsland = island
                newDay.day = day.rawValue
                return newDay
            }
        } catch {
            print("Error fetching or creating AppDayOfWeek: \(error)")
            return nil
        }
    }

    // Delete schedules at specified offsets for a given day and island
    func deleteSchedule(at indexSet: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pirateIsland == %@ AND day == %@", island, day.rawValue)
        
        do {
            let results = try persistence.container.viewContext.fetch(fetchRequest)
            for index in indexSet {
                persistence.container.viewContext.delete(results[index])
            }
            saveContext()
        } catch {
            print("Error deleting schedule: \(error.localizedDescription)")
        }
    }


    // Fetch schedules for a specific pirate island
    func fetchSchedules(for island: PirateIsland) -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(island.name ?? "Unknown")")
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pirateIsland == %@", island)
        do {
            return try persistence.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching schedules: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteRecord(for appDayOfWeek: AppDayOfWeek) {
        print("AppDayOfWeekRepository - Deleting record for AppDayOfWeek: \(appDayOfWeek.name ?? "Unknown")")
        persistence.container.viewContext.delete(appDayOfWeek)
        saveContext()
    }
}
