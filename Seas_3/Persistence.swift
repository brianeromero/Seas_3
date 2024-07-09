// Persistence.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import Combine
import Foundation
import CoreData

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    private init() {
        container = NSPersistentContainer(name: "Seas_3")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }

    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    func deleteSchedule(at offsets: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        let daySchedules = fetchAppDayOfWeek(for: island, day: day)

        for index in offsets {
            let scheduleToDelete = daySchedules[index]
            container.viewContext.delete(scheduleToDelete)
        }

        saveContext()
    }

    func fetchSchedules(for island: PirateIsland) -> [AppDayOfWeek] {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "pIsland == %@", island)
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch schedules: \(error)")
            return []
        }
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    // MARK: - Fetch PirateIslands

    func fetchAllPirateIslands() -> [PirateIsland] {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            let pirateIslands = try container.viewContext.fetch(fetchRequest)
            print("Fetched \(pirateIslands.count) PirateIsland objects.")
            return pirateIslands
        } catch {
            print("Error fetching PirateIslands: \(error)")
            return []
        }
    }

    // MARK: - Fetch Last PirateIsland

    func fetchLastPirateIsland() -> PirateIsland? {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: false)]
        fetchRequest.fetchLimit = 1

        do {
            let results = try container.viewContext.fetch(fetchRequest)
            if let lastIsland = results.first {
                print("Fetched Last Pirate Island: \(lastIsland.islandName)")
                return lastIsland
            } else {
                print("No pirate islands found.")
                return nil
            }
        } catch {
            print("Error fetching last pirate island: \(error)")
            return nil
        }
    }

    // MARK: - Fetch AppDayOfWeeks

    func fetchAllAppDayOfWeeks() -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        do {
            let appDayOfWeeks = try container.viewContext.fetch(fetchRequest)
            print("Fetched \(appDayOfWeeks.count) AppDayOfWeek objects.")
            return appDayOfWeeks
        } catch {
            print("Error fetching AppDayOfWeeks: \(error)")
            return []
        }
    }

    // MARK: - Fetch Specific AppDayOfWeek by Island and Day

    func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            let results = try container.viewContext.fetch(fetchRequest)
            return results
        } catch {
            print("Error fetching AppDayOfWeek: \(error)")
            return []
        }
    }

    // MARK: - Fetch or Create AppDayOfWeek

    func fetchOrCreateAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            if let result = try container.viewContext.fetch(fetchRequest).first {
                return result
            } else {
                let newAppDayOfWeek = AppDayOfWeek(context: container.viewContext)
                newAppDayOfWeek.pIsland = island
                newAppDayOfWeek.day = day.rawValue
                return newAppDayOfWeek
            }
        } catch {
            fatalError("Error fetching or creating AppDayOfWeek: \(error)")
        }
    }

    // MARK: - Create New AppDayOfWeek

    func createAppDayOfWeek(pIsland: PirateIsland, dayOfWeek: String, matTime: String?, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?) -> AppDayOfWeek {
        let newAppDayOfWeek = AppDayOfWeek(context: container.viewContext)
        newAppDayOfWeek.pIsland = pIsland
        newAppDayOfWeek.matTime = matTime
        newAppDayOfWeek.gi = gi
        newAppDayOfWeek.noGi = noGi
        newAppDayOfWeek.openMat = openMat
        newAppDayOfWeek.restrictions = restrictions
        newAppDayOfWeek.restrictionDescription = restrictionDescription
        newAppDayOfWeek.day = dayOfWeek

        saveContext()
        return newAppDayOfWeek
    }

    // MARK: - Preview Persistence Controller

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        for _ in 0..<10 {
            let newIsland = PirateIsland(context: viewContext)
            newIsland.islandName = "Preview Island"
            newIsland.latitude = 37.7749
            newIsland.longitude = -122.4194
            newIsland.createdTimestamp = Date()
            newIsland.islandLocation = "San Francisco, CA"
            // Set other required attributes as needed
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return result
    }()

    private init(inMemory: Bool) {
        container = NSPersistentContainer(name: "Seas_3")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - FetchRequestProvider Conformance

    func fetchAll() -> [PirateIsland] {
        fetchAllPirateIslands()
    }

    func fetchLast() -> PirateIsland? {
        fetchLastPirateIsland()
    }
}
