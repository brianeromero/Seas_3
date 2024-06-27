import Foundation
import CoreData

class PirateIslandViewModel: ObservableObject {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func createPirateIsland(name: String, location: String, daysOfWeek: [AppDayOfWeek]) {
        print("Creating pirate island with name: \(name), location: \(location), daysOfWeek count: \(daysOfWeek.count)")

        // Check if an island with the same name already exists
        if let existingIsland = fetchPirateIsland(name: name) {
            print("Pirate island with name \(name) already exists. Skipping creation.")
            return
        }

        let newIsland = PirateIsland(context: context)
        newIsland.islandName = name
        newIsland.islandLocation = location
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = "defaultUserId" // Replace with appropriate user ID
        newIsland.lastModifiedByUserId = "defaultUserId" // Replace with appropriate user ID
        newIsland.lastModifiedTimestamp = Date()

        let mutableDaysOfWeek = newIsland.mutableSetValue(forKey: "daysOfWeek")
        
        for day in daysOfWeek {
            mutableDaysOfWeek.add(day)
        }

        saveContext()
    }

    func fetchPirateIsland(name: String) -> PirateIsland? {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName == %@", name)
        
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Failed to fetch data: \(error)")
            return nil
        }
    }

    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("Context saved successfully.")
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}
