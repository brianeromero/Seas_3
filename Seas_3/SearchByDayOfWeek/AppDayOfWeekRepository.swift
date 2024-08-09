// AppDayOfWeekRepository.swift
// Seas_3
//
// Created by Brian Romero on 6/25/24.

import Foundation
import SwiftUI
import CoreData

class AppDayOfWeekRepository {
    private let persistenceController: PersistenceController
    private var currentAppDayOfWeek: AppDayOfWeek? // Add this line if needed
    private var selectedIsland: PirateIsland? // Add this line


    
    // Public initializer
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        print("AppDayOfWeekRepository initialized")

    }
    
    // Shared instance for singleton pattern
    static let shared: AppDayOfWeekRepository = {
        let persistence = PersistenceController.shared
        return AppDayOfWeekRepository(persistenceController: persistence)
    }()
    
    
    // Method to set the selected island
    func setSelectedIsland(_ island: PirateIsland) {
        self.selectedIsland = island
    }

    // Method to set the current AppDayOfWeek
    func setCurrentAppDayOfWeek(_ appDayOfWeek: AppDayOfWeek) {
        self.currentAppDayOfWeek = appDayOfWeek
    }

    
    // Your methods including performActionThatDependsOnIslandAndDay()
    func performActionThatDependsOnIslandAndDay() {
        guard let island = selectedIsland, let appDay = currentAppDayOfWeek else {
            print("Selected island or current day of week is not set.")
            return
        }

        // Safely unwrap day from appDay
        guard let dayString = appDay.day, let day = DayOfWeek(rawValue: dayString) else {
            print("Invalid day of week.")
            return
        }

        _ = createAppDayOfWeek(with: island, dayOfWeek: day)
        // Perform additional actions...
    }


    
    func saveContext() {
        print("AppDayOfWeekRepository - Saving context")
        self.persistenceController.saveContext()
    }

    func generateName(for island: PirateIsland, day: DayOfWeek) -> String {
        return "\(island.islandName) \(day.displayName)"
    }
    
    func generateAppDayOfWeekID(for island: PirateIsland, day: DayOfWeek) -> String {
        return "\(island.islandName)-\(day.rawValue)"
    }

    func createAppDayOfWeek(with island: PirateIsland, dayOfWeek: DayOfWeek) -> AppDayOfWeek? {
        return fetchOrCreateAppDayOfWeek(for: dayOfWeek.rawValue, pirateIsland: island)
    }


    func updateAppDayOfWeekName(_ appDayOfWeek: AppDayOfWeek, with island: PirateIsland, dayOfWeek: DayOfWeek) {
        appDayOfWeek.name = generateName(for: island, day: dayOfWeek)
        appDayOfWeek.appDayOfWeekID = generateAppDayOfWeekID(for: island, day: dayOfWeek)
        saveContext()
    }

    func updateAppDayOfWeek(_ appDayOfWeek: AppDayOfWeek, with island: PirateIsland, dayOfWeek: DayOfWeek) {
        updateAppDayOfWeekName(appDayOfWeek, with: island, dayOfWeek: dayOfWeek)
        // Add any additional updates here
    }

    
    func fetchAllAppDayOfWeeks() -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching all AppDayOfWeeks")
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        return performFetch(request: fetchRequest)
    }

    func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        fetchRequest.fetchLimit = 1

        do {
            let results = try persistenceController.container.viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching AppDayOfWeek: \(error)")
            return nil
        }
    }
    
    func getAppDayOfWeek(for island: PirateIsland, dayOfWeek: DayOfWeek) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, dayOfWeek.rawValue)
        fetchRequest.fetchLimit = 1

        return PersistenceController.shared.fetch(request: fetchRequest).first
    }

    func fetchOrCreateAppDayOfWeek(for day: String, pirateIsland: PirateIsland) -> AppDayOfWeek {
        guard let context = pirateIsland.managedObjectContext else {
            fatalError("PirateIsland's managedObjectContext is nil")
        }
        
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day == %@ AND pIsland == %@", day, pirateIsland)
        
        do {
            let appDayOfWeeks = try context.fetch(fetchRequest)
            if let appDayOfWeek = appDayOfWeeks.first {
                return appDayOfWeek
            } else {
                let newAppDayOfWeek = AppDayOfWeek(context: context)
                newAppDayOfWeek.day = day
                newAppDayOfWeek.pIsland = pirateIsland
                return newAppDayOfWeek
            }
        } catch {
            fatalError("Failed to fetch or create AppDayOfWeek: \(error)")
        }
    }

    func addNewAppDayOfWeek(for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else {
            print("Error: selectedIsland is nil")
            return
        }

        let newAppDayOfWeek = fetchOrCreateAppDayOfWeek(for: day.rawValue, pirateIsland: selectedIsland)
        currentAppDayOfWeek = newAppDayOfWeek
        print("Created or fetched AppDayOfWeek: \(newAppDayOfWeek)")
    }

    func deleteSchedule(at indexSet: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            let results = try persistenceController.container.viewContext.fetch(fetchRequest)
            for index in indexSet {
                let dayToDelete = results[index]
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

    func fetchSchedules(for island: PirateIsland) -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(island.islandName)")
        let predicate = NSPredicate(format: "pIsland == %@", island)
        return persistenceController.fetchSchedules(for: predicate)
    }

    func fetchSchedules(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(island.islandName) and day: \(day.displayName)")
        let predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        return persistenceController.fetchSchedules(for: predicate)
    }

    func deleteRecord(for appDayOfWeek: AppDayOfWeek) {
        print("AppDayOfWeekRepository - Deleting record for AppDayOfWeek: \(appDayOfWeek.appDayOfWeekID ?? "Unknown")")
        if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
            for matTime in matTimes {
                persistenceController.container.viewContext.delete(matTime)
            }
        }
        persistenceController.container.viewContext.delete(appDayOfWeek)
        saveContext()
    }

    private func performFetch(request: NSFetchRequest<AppDayOfWeek>) -> [AppDayOfWeek] {
        do {
            return try persistenceController.container.viewContext.fetch(request)
        } catch {
            print("Fetch error: \(error.localizedDescription)")
            return []
        }
    }
    
    
    
}
