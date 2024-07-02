//
//  Persistence.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//

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

    func fetchAppDayOfWeek(byID id: NSManagedObjectID) -> AppDayOfWeek? {
        do {
            guard let object = try container.viewContext.existingObject(with: id) as? AppDayOfWeek else {
                print("Object with ID \(id) does not exist or cannot be cast to AppDayOfWeek")
                return nil
            }
            return object
        } catch {
            print("Error fetching AppDayOfWeek by ID: \(error)")
            return nil
        }
    }

    // MARK: - Create New AppDayOfWeek

    func createAppDayOfWeek(sunday: Bool, monday: Bool, tuesday: Bool, wednesday: Bool, thursday: Bool, friday: Bool, saturday: Bool, matTime: String?, restrictions: Bool, restrictionDescription: String?, op_sunday: Bool, op_monday: Bool, op_tuesday: Bool, op_wednesday: Bool, op_thursday: Bool, op_friday: Bool, op_saturday: Bool, gi: Bool, noGi: Bool, selectedDays: [String]) -> AppDayOfWeek {
        let newAppDayOfWeek = AppDayOfWeek(context: container.viewContext)
        newAppDayOfWeek.sunday = sunday
        newAppDayOfWeek.monday = monday
        newAppDayOfWeek.tuesday = tuesday
        newAppDayOfWeek.wednesday = wednesday
        newAppDayOfWeek.thursday = thursday
        newAppDayOfWeek.friday = friday
        newAppDayOfWeek.saturday = saturday
        newAppDayOfWeek.matTime = matTime
        newAppDayOfWeek.restrictions = restrictions
        newAppDayOfWeek.restrictionDescription = restrictionDescription
        newAppDayOfWeek.op_sunday = op_sunday
        newAppDayOfWeek.op_monday = op_monday
        newAppDayOfWeek.op_tuesday = op_tuesday
        newAppDayOfWeek.op_wednesday = op_wednesday
        newAppDayOfWeek.op_thursday = op_thursday
        newAppDayOfWeek.op_friday = op_friday
        newAppDayOfWeek.op_saturday = op_saturday
        newAppDayOfWeek.gi = gi
        newAppDayOfWeek.noGi = noGi

        saveContext()

        return newAppDayOfWeek
    }

    // MARK: - Preview Persistence Controller

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Create sample data for preview
        let newPirateIsland = PirateIsland(context: viewContext)
        newPirateIsland.islandName = "Preview Island"
        newPirateIsland.latitude = 37.7749
        newPirateIsland.longitude = -122.4194

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
}
