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

    @Published var container: NSPersistentContainer // Use @Published to trigger updates

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

    // Preview context setup
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        // Populate with dummy data for previews if needed
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
    }
}
