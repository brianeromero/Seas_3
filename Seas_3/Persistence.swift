// Persistence.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import Foundation
import CoreData
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    @Published var someStateVariable: Int = 0

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

    // MARK: - Fetch Specific AppDayOfWeek by ID

    func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek, fetchFirstOnly: Bool = false) -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND name == %@", island, day.displayName)

        do {
            let results = try container.viewContext.fetch(fetchRequest)
            if fetchFirstOnly {
                return results.isEmpty ? [] : [results.first!]
            } else {
                return results
            }
        } catch {
            print("Error fetching AppDayOfWeek: \(error)")
            return []
        }
    }

    // MARK: - Create New AppDayOfWeek

    func createAppDayOfWeek(pIsland: PirateIsland, dayOfWeek: DayOfWeek, matTime: String?, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?) -> AppDayOfWeek {
        let newAppDayOfWeek = AppDayOfWeek(context: container.viewContext)
        newAppDayOfWeek.pIsland = pIsland
        newAppDayOfWeek.name = dayOfWeek.displayName // Assuming name is used to identify the day
        newAppDayOfWeek.matTime = matTime
        newAppDayOfWeek.gi = gi
        newAppDayOfWeek.noGi = noGi
        newAppDayOfWeek.openMat = openMat
        newAppDayOfWeek.restrictions = restrictions
        newAppDayOfWeek.restrictionDescription = restrictionDescription
        
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
    
    func fetchOrCreateAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "pIsland == %@ AND name == %@", island, day.displayName) // Use displayName
        
        do {
            if let existingDay = try container.viewContext.fetch(request).first {
                return existingDay
            } else {
                let newDay = AppDayOfWeek(context: container.viewContext)
                newDay.pIsland = island
                newDay.name = day.displayName // Use displayName
                return newDay
            }
        } catch {
            print("Error fetching or creating AppDayOfWeek: \(error.localizedDescription)")
            fatalError("Failed to fetch or create AppDayOfWeek: \(error)")
        }
    }
    
}
