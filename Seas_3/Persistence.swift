// Persistence.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import Combine
import Foundation
import CoreData
import UIKit

class PersistenceController: ObservableObject {
    static let shared = PersistenceController(inMemory: false)
    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Seas_3")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("Persistent stores loaded successfully")
            print("Store descriptions: \(self.container.persistentStoreDescriptions)")
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        print("View context setup complete")
    }

    // General fetch method
    func fetch<T: NSManagedObject>(request: NSFetchRequest<T>) -> [T] {
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    // General create method
    func create<T: NSManagedObject>(entityName: String) -> T? {
        let context = container.viewContext
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            print("Entity \(entityName) not found")
            return nil
        }
        return T(entity: entity, insertInto: context)
    }

    // Save context method
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Context saved successfully")
            } catch {
                print("Save error: \(error.localizedDescription)")
            }
        }
    }

    // General delete method
    func delete<T: NSManagedObject>(_ object: T) {
        container.viewContext.delete(object)
        saveContext()
    }

    // Specific fetch and delete methods
    func deleteAppDayOfWeek(at offsets: IndexSet, for island: PirateIsland, day: DayOfWeek) {
        let daySchedules = fetchAppDayOfWeekForIslandAndDay(for: island, day: day)
        for index in offsets {
            let scheduleToDelete = daySchedules[index]
            container.viewContext.delete(scheduleToDelete)
        }
        saveContext()
    }

    func fetchSchedules(for predicate: NSPredicate) -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        return fetch(request: fetchRequest)
    }

    func fetchAllPirateIslands() -> [PirateIsland] {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        return fetch(request: fetchRequest)
    }

    func fetchLastPirateIsland() -> PirateIsland? {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: false)]
        fetchRequest.fetchLimit = 1
        return fetch(request: fetchRequest).first
    }

    func fetchAppDayOfWeekForIslandAndDay(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        return fetch(request: fetchRequest)
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
}
