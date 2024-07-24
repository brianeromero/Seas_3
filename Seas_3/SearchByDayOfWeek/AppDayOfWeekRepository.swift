//
//  AppDayOfWeekRepository.swift
//  Seas_3
//
//  Created by Brian Romero on 6/25/24.
//

import Foundation
import CoreData

class AppDayOfWeekRepository: NSObject {
    static let shared = AppDayOfWeekRepository(persistence: PersistenceController.shared) // Define shared instance

    let persistenceController: PersistenceController

    init(persistence: PersistenceController) {
        self.persistenceController = persistence
    }

    // Save changes to the CoreData context
    func saveContext() {
        print("AppDayOfWeekRepository - Saving context")
        persistenceController.saveContext()
    }
    
    // Fetch all AppDayOfWeek entities
    func fetchAllAppDayOfWeeks() -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching all AppDayOfWeeks")
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"] // Prefetch relationships if necessary
        do {
            return try persistenceController.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching AppDayOfWeeks: \(error.localizedDescription)")
            return []
        }
    }

    // Fetch specific AppDayOfWeek for a given island and day
    func fetchAppDayOfWeekFromPersistence(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        return persistenceController.fetchAppDayOfWeekForIslandAndDay(for: island, day: day)
    }

    // Fetch or create AppDayOfWeek for a given island and day
    func fetchOrCreateAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            if let existingDay = try persistenceController.container.viewContext.fetch(fetchRequest).first {
                return existingDay
            } else {
                let newDay = AppDayOfWeek(context: persistenceController.container.viewContext)
                newDay.pIsland = island
                newDay.day = day.rawValue
                newDay.name = generateNameForDay(day: day) // Generate and set the name
                
                saveContext() // Save the new record
                return newDay
            }
        } catch {
            print("Error fetching or creating AppDayOfWeek: \(error)")
            return nil
        }
    }

    // Generate name for the given day
    private func generateNameForDay(day: DayOfWeek) -> String {
        return "\(day.rawValue) Schedule" // Example name generation logic
    }

    // Add MatTimes for a given day and island
    func addMatTimesForDay(day: DayOfWeek, matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, adult: Bool)], for island: PirateIsland) {
        // Fetch or create AppDayOfWeek for the specified day and island
        guard let appDayOfWeek = fetchOrCreateAppDayOfWeek(for: island, day: day) else {
            print("Failed to fetch or create AppDayOfWeek for day: \(day)")
            return
        }

        // Process each MatTime entry
        matTimes.forEach { matTimeData in
            let newMatTime = MatTime(context: persistenceController.container.viewContext)
            newMatTime.time = matTimeData.time
            newMatTime.type = matTimeData.type
            newMatTime.gi = matTimeData.gi
            newMatTime.noGi = matTimeData.noGi
            newMatTime.openMat = matTimeData.openMat
            newMatTime.restrictions = matTimeData.restrictions
            newMatTime.restrictionDescription = matTimeData.restrictionDescription
            newMatTime.goodForBeginners = matTimeData.goodForBeginners
            newMatTime.adult = matTimeData.adult

            appDayOfWeek.addToMatTimes(newMatTime)
        }

        saveContext()  // Save the changes
    }





    // Delete schedules at specified offsets for a given day and island
    func deleteSchedule(at indexSet: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            let results = try persistenceController.container.viewContext.fetch(fetchRequest)
            for index in indexSet {
                let dayToDelete = results[index]
                // Remove associated MatTimes before deleting AppDayOfWeek
                if let matTimes = dayToDelete.matTimes as? Set<MatTime> {
                    for matTime in matTimes {
                        persistenceController.container.viewContext.delete(matTime)
                    }
                }
                persistenceController.container.viewContext.delete(dayToDelete)
            }
            saveContext()
        } catch {
            print("Error deleting schedule: \(error.localizedDescription)")
        }
    }

    // Fetch schedules for a specific pirate island
    func fetchSchedules(for island: PirateIsland) -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(island.islandName)")
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@", island)
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]

        do {
            return try persistenceController.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching schedules: \(error.localizedDescription)")
            return []
        }
    }

    // Delete a specific AppDayOfWeek record
    func deleteRecord(for appDayOfWeek: AppDayOfWeek) {
        print("AppDayOfWeekRepository - Deleting record for AppDayOfWeek: \(appDayOfWeek.appDayOfWeekID ?? "Unknown")")
        // Remove associated MatTimes before deleting AppDayOfWeek
        if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
            for matTime in matTimes {
                persistenceController.container.viewContext.delete(matTime)
            }
        }
        persistenceController.container.viewContext.delete(appDayOfWeek)
        saveContext()
    }

    // Fetch current AppDayOfWeek for a specific pirate island
    func fetchCurrentDayOfWeek(for island: PirateIsland) -> AppDayOfWeek? {
        let currentDayOfWeek = Calendar.current.component(.weekday, from: Date()) // Get current day of week (1-7, where 1 is Sunday)
        guard let day = DayOfWeek(rawValue: "\(currentDayOfWeek)") else {
            print("Invalid day of week")
            return nil
        }

        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            return try persistenceController.container.viewContext.fetch(fetchRequest).first
        } catch {
            print("Error fetching current day of week: \(error.localizedDescription)")
            return nil
        }
    }
}
