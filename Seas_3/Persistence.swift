// Persistence.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import Combine
import Foundation
import CoreData
import UIKit

// Notification Name extension
extension Notification.Name {
    static let contextSaved = Notification.Name("contextSaved")
}

class PersistenceController: ObservableObject {
    static let shared = PersistenceController(inMemory: false)
    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Seas_3")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        viewContext.automaticallyMergesChangesFromParent = true
    }

    // General fetch method
    func fetch<T: NSManagedObject>(request: NSFetchRequest<T>) throws -> [T] {
        do {
            return try viewContext.fetch(request)
        } catch {
            throw PersistenceError.fetchError(error)
        }
    }

    // General create method
    func create<T: NSManagedObject>(entityName: String) -> T? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: viewContext) else {
            return nil
        }
        return T(entity: entity, insertInto: viewContext)
    }

    // Save context method
    func saveContext() throws {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
                NotificationCenter.default.post(name: .contextSaved, object: nil)
            } catch {
                print("Error saving context: \(error.localizedDescription)")
                throw PersistenceError.saveError(error)
            }
        }
    }

    // Delete method
    func deleteAppDayOfWeek(at offsets: IndexSet, for island: PirateIsland, day: DayOfWeek) {
        let daySchedules = fetchAppDayOfWeekForIslandAndDay(for: island, day: day)
        for index in offsets {
            let scheduleToDelete = daySchedules[index]
            viewContext.delete(scheduleToDelete)
        }
        do {
            try saveContext() // Catch the error
        } catch {
            print("Failed to save context after deletion: \(error.localizedDescription)")
        }
    }

    // Specific fetch methods
    func fetchSchedules(for predicate: NSPredicate) -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        do {
            return try fetch(request: fetchRequest)
        } catch {
            print("Error fetching schedules: \(error)")
            return []
        }
    }
    
    // Custom error enum
    enum PersistenceError: Error {
        case fetchError(Error)
        case saveError(Error)
    }

    func fetchAllPirateIslands() -> [PirateIsland] {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            return try fetch(request: fetchRequest)
        } catch {
            print("Error fetching islands: \(error)")
            return []
        }
    }

    func fetchLastPirateIsland() -> PirateIsland? {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: false)]
        fetchRequest.fetchLimit = 1
        do {
            let results = try fetch(request: fetchRequest)
            return results.first
        } catch {
            print("Error fetching last island: \(error)")
            return nil
        }
    }

    func fetchAppDayOfWeekForIslandAndDay(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        do {
            return try fetch(request: fetchRequest)
        } catch {
            print("Error fetching app day of week: \(error)")
            return []
        }
    }

    // MARK: - Preview Persistence Controller
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.viewContext

        for _ in 0..<10 {
            let newIsland = PirateIsland(context: viewContext)
            newIsland.islandID = UUID() // Set the islandID
            newIsland.islandName = "Preview Gym"
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
}
