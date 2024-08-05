// AppDayOfWeekRepository.swift
// Seas_3
//
// Created by Brian Romero on 6/25/24.

import Foundation
import CoreData

class AppDayOfWeekRepository {
    static let shared: AppDayOfWeekRepository = {
        let persistence = PersistenceController.shared
        return AppDayOfWeekRepository(persistence: persistence)
    }()

    let persistenceController: PersistenceController

    private init(persistence: PersistenceController) {
        self.persistenceController = persistence
    }

    func saveContext() {
        print("AppDayOfWeekRepository - Saving context")
        self.persistenceController.saveContext()
    }

    func fetchAllAppDayOfWeeks() -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching all AppDayOfWeeks")
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        do {
            return try persistenceController.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching AppDayOfWeeks: \(error.localizedDescription)")
            return []
        }
    }

    func fetchAppDayOfWeekFromPersistence(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching AppDayOfWeek: \(error.localizedDescription)")
            return []
        }
    }

    func fetchOrCreateAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek? {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            if let existingDay = try context.fetch(fetchRequest).first {
                return existingDay
            } else {
                let newDay = AppDayOfWeek(context: context)
                newDay.pIsland = island
                newDay.day = day.rawValue
                newDay.name = generateNameForDay(day: day)
                newDay.appDayOfWeekID = generateAppDayOfWeekID(island: island, day: day.rawValue)
                saveContext()
                return newDay
            }
        } catch {
            print("Error fetching or creating AppDayOfWeek: \(error.localizedDescription)")
            return nil
        }
    }

    private func generateNameForDay(day: DayOfWeek) -> String {
        return "\(day.displayName) Schedule"
    }

    private func generateAppDayOfWeekID(island: PirateIsland, day: String) -> String {
        return "\(island.name ?? "UnknownIsland")_\(day)_\(DayOfWeek(rawValue: day)?.number ?? 0)"
    }

    func addMatTimesForDay(day: DayOfWeek, matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, adult: Bool)], for island: PirateIsland) {
        let context = persistenceController.container.viewContext

        guard let appDayOfWeek = fetchOrCreateAppDayOfWeek(for: island, day: day) else {
            print("Failed to fetch or create AppDayOfWeek for day: \(day)")
            return
        }

        matTimes.forEach { matTimeData in
            let newMatTime = MatTime(context: context)
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

        saveContext()
    }

    func deleteSchedule(at indexSet: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            let results = try context.fetch(fetchRequest)
            for index in indexSet {
                let dayToDelete = results[index]
                if let matTimes = dayToDelete.matTimes as? Set<MatTime> {
                    for matTime in matTimes {
                        context.delete(matTime)
                    }
                }
                context.delete(dayToDelete)
            }
            saveContext()
        } catch {
            print("Error deleting schedule: \(error.localizedDescription)")
        }
    }

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

    func deleteRecord(for appDayOfWeek: AppDayOfWeek) {
        print("AppDayOfWeekRepository - Deleting record for AppDayOfWeek: \(appDayOfWeek.appDayOfWeekID ?? "Unknown")")
        let context = persistenceController.container.viewContext
        if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
            for matTime in matTimes {
                context.delete(matTime)
            }
        }
        context.delete(appDayOfWeek)
        saveContext()
    }

    func fetchAppDayOfWeek(for island: PirateIsland) -> [AppDayOfWeek] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@", island)
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error.localizedDescription)")
            return []
        }
    }
}
