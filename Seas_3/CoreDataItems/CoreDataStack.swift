//
//  CoreDataStack.swift
//  Seas_3
//
//  Created by Brian Romero on 6/25/24.
//
import Foundation
import CoreData
import Combine

class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()

    private init() {
        Self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Seas_3")

        container.loadPersistentStores(completionHandler: { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })

        return container
    }()

    var viewContext: NSManagedObjectContext {
        return Self.persistentContainer.viewContext
    }

    func saveContext() {
        let context = Self.persistentContainer.viewContext
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
        return Self.persistentContainer.newBackgroundContext()
    }
}
