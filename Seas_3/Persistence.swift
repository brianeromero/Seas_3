// Persistence.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import Combine
import Foundation
import CoreData
import UIKit
import FirebaseFirestore
import Firebase

extension Notification.Name {
    static let contextSaved = Notification.Name("contextSaved")
}

class PersistenceController: ObservableObject {
    // Singleton instance
    static let shared = PersistenceController()

    // Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        for _ in 0..<5 {
            let sampleIsland = PirateIsland(context: viewContext)
            sampleIsland.islandID = UUID()
            sampleIsland.islandName = "Sample Gym"
            sampleIsland.islandLocation = "Sample Location"
        }

        do {
            try viewContext.save()
        } catch {
            fatalError("Unresolved error \(error.localizedDescription)")
        }

        return controller
    }()

    // Core Data container
    let container: NSPersistentContainer

    // Firestore reference (optional)
    private let db: Firestore?

    // ViewContext for accessing Core Data
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // Add this method to configure Firestore
    func configure(db: Firestore) {
        // Store Firestore instance or configure other settings if needed
        self.firestore = db
    }

    private var firestore: Firestore?

    // Initializer
    init(db: Firestore? = nil, inMemory: Bool = false) {
        self.db = db
        container = NSPersistentContainer(name: "Seas_3") // Use your Core Data model name
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        viewContext.automaticallyMergesChangesFromParent = true
    }

    // Core Data methods
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        return try viewContext.fetch(request)
    }

    func create<T: NSManagedObject>(entityName: String) -> T? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: viewContext) else { return nil }
        return T(entity: entity, insertInto: viewContext)
    }

    func saveContext() async throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }

    // Firestore Syncing
    func syncPirateIslandsFromFirestore() async throws {
        guard let db = db else { return }
        let snapshot = try await db.collection("pirateIslands").getDocuments()
        
        for document in snapshot.documents {
            guard let islandID = UUID(uuidString: document.documentID) else { continue }
            let name = document.get("name") as? String ?? ""
            let location = document.get("location") as? String ?? ""
            
            let pirateIsland = PirateIsland(context: viewContext)
            pirateIsland.islandID = islandID
            pirateIsland.islandName = name
            pirateIsland.islandLocation = location
        }
        
        try await saveContext()
    }

    // Pirate Island methods
    func fetchAllPirateIslands() async throws -> [PirateIsland] {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        return try await fetch(fetchRequest)
    }

    func createOrUpdatePirateIsland(
        islandID: UUID,
        name: String,
        location: String,
        country: String,
        createdByUserId: String,
        latitude: Double,
        longitude: Double,
        gymWebsiteURL: URL?
    ) async throws -> PirateIsland {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", islandID as CVarArg)

        if let existingIsland = try await fetch(fetchRequest).first {
            // Update existing island
            existingIsland.islandName = name
            existingIsland.islandLocation = location
            existingIsland.country = country
            existingIsland.createdByUserId = createdByUserId
            existingIsland.latitude = latitude
            existingIsland.longitude = longitude
            existingIsland.gymWebsite = gymWebsiteURL
            return existingIsland
        } else {
            // Create new island
            let pirateIsland = PirateIsland(context: viewContext)
            pirateIsland.islandID = islandID
            pirateIsland.islandName = name
            pirateIsland.islandLocation = location
            pirateIsland.country = country
            pirateIsland.createdByUserId = createdByUserId
            pirateIsland.latitude = latitude
            pirateIsland.longitude = longitude
            pirateIsland.gymWebsite = gymWebsiteURL
            return pirateIsland
        }
    }

    // Sync Firestore data into Core Data
    func cachePirateIslandsFromFirestore() async throws {
        print("Fetching pirate islands from Firestore...")

        let snapshot = try await db!.collection("pirateIslands").getDocuments()
        print("Fetched \(snapshot.documents.count) pirate islands from Firestore")

        for document in snapshot.documents {
            guard let islandID = UUID(uuidString: document.documentID) else {
                print("Invalid document ID: \(document.documentID)")
                continue
            }

            let name = document.get("name") as? String ?? ""
            let location = document.get("location") as? String ?? ""
            let country = document.get("country") as? String ?? ""
            let createdByUserId = document.get("createdByUserId") as? String ?? ""
            let latitude = document.get("latitude") as? Double ?? 0
            let longitude = document.get("longitude") as? Double ?? 0
            let gymWebsiteURL = URL(string: document.get("gymWebsiteURL") as? String ?? "")

            let pirateIsland = try await createOrUpdatePirateIsland(
                islandID: islandID,
                name: name,
                location: location,
                country: country,
                createdByUserId: createdByUserId,
                latitude: latitude,
                longitude: longitude,
                gymWebsiteURL: gymWebsiteURL
            )

            print("Updated/created pirate island with ID: \(islandID)")
        }

        try await saveContext()
        print("Saved pirate islands to Core Data")
    }

    // Fetch specific entity from Core Data or Firebase
    func fetchSingle(entityName: String) async throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.fetchLimit = 1
        if let result = try container.viewContext.fetch(fetchRequest).first {
            return result
        }

        // If not found in Core Data, fetch from Firebase
        if entityName == "PirateIsland" {
            let fetchedIsland = try await fetchPirateIslandFromFirebase()

            // Cache the result into Core Data if found in Firebase
            if let island = fetchedIsland {
                let islandEntity = NSEntityDescription.entity(forEntityName: "PirateIsland", in: container.viewContext)!
                let pirateIsland = PirateIsland(entity: islandEntity, insertInto: container.viewContext)
                pirateIsland.islandID = UUID(uuidString: "\(island.id)")
                pirateIsland.islandName = island.islandName
                // Map other attributes
                try await saveContext()
                return pirateIsland
            }
        }

        return nil
    }

    func fetchPirateIslandFromFirebase() async throws -> PirateIsland? {
        let snapshot = try await db!.collection("pirateIslands").limit(to: 1).getDocuments()
        guard let document = snapshot.documents.first else {
            return nil
        }

        let island = PirateIsland(context: viewContext)
        island.islandID = UUID(uuidString: document.documentID)
        island.islandName = document.get("islandName") as? String
        return island
    }
    
    func fetchLocalRecords(forCollection collectionName: String) async throws -> [String]? {
        switch collectionName {
        case "pirateIslands":
            return try await fetchLocalRecords(forEntity: PirateIsland.self, keyPath: \.islandID!) as [String]
        case "reviews":
            return try await fetchLocalRecords(forEntity: Review.self, keyPath: \.reviewID)
        case "matTimes":
            return try await fetchLocalRecords(forEntity: MatTime.self, keyPath: \.id!) as [String]
        default:
            throw PersistenceError.invalidCollectionName(collectionName)
        }
    }

    func fetchLocalRecords<T: NSManagedObject>(forEntity entity: T.Type, keyPath: KeyPath<T, UUID>) async throws -> [String] {
        do {
            let fetchRequest = entity.fetchRequest()
            let records = try viewContext.fetch(fetchRequest) as? [T] ?? []
            return records.compactMap { $0[keyPath: keyPath].uuidString }
        } catch {
            throw PersistenceError.fetchError(error)
        }
    }

    // Custom error enum
    enum PersistenceError: Error, CustomStringConvertible {
        case fetchError(Error)
        case saveError(Error)
        case invalidCollectionName(String)

        var description: String {
            switch self {
            case .fetchError(let error):
                return "Fetch error: \(error.localizedDescription)"
            case .saveError(let error):
                return "Save error: \(error.localizedDescription)"
            case .invalidCollectionName(let name):
                return "Invalid collection name: \(name)"
            }
        }
    }
}

extension PersistenceController {
    // This method fetches schedules based on a predicate (such as island and day)
    func fetchSchedules(for predicate: NSPredicate) async throws -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = predicate
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results
        } catch {
            throw error
        }
    }
}
