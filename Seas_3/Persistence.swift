//
//  Persistence.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//
import CoreData
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    @Published private(set) var viewContext: NSManagedObjectContext // Expose viewContext for observation

    private init() {
        container = NSPersistentContainer(name: "Seas_3")

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        viewContext = container.viewContext // Initialize viewContext
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

    // Preview context setup
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)

        // Seed some test data for preview
        for i in 0..<5 {
            // Inside the preview initializer of PersistenceController
            for i in 0..<5 {
                let island = PirateIsland(context: controller.viewContext)
                island.islandName = "Island \(i)"
                island.latitude = 37.7749 + Double(i)
                island.longitude = -122.4194 + Double(i)
                
                // Set required attributes
                island.createdByUserId = "sampleUserId" // Replace with actual user ID logic
                island.createdTimestamp = Date() // Set the current date and time
                island.islandLocation = "Sample Location" // Set the location details
                island.lastModifiedByUserId = "sampleUserId" // Replace with actual user ID logic
                island.lastModifiedTimestamp = Date() // Set the current date and time
                
                // Ensure all required attributes are set appropriately
            }
            // Set other required attributes
        }

        do {
            try controller.viewContext.save()
        } catch {
            fatalError("Failed to seed preview context: \(error)")
        }

        return controller
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

        viewContext = container.viewContext // Initialize viewContext
    }
}
