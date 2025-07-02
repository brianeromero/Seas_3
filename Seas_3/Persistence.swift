// Persistence.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import Combine
import Foundation
import CoreData
import UIKit
import FirebaseFirestore
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore


extension Notification.Name {
    static let contextSaved = Notification.Name("contextSaved")
}

class PersistenceController: ObservableObject {
    // MARK: - Singleton Instances
    static let shared = PersistenceController()

    // MARK: - Core Data
    let container: NSPersistentContainer
    let firestoreManager: FirestoreManager

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    
    // MARK: - Preview Provider (This block should be INSIDE the class)
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // Add some dummy data for your preview if IslandMenu2 relies on it
        // For example, a dummy PirateIsland:
        let dummyIsland = PirateIsland(context: viewContext)
        dummyIsland.islandID = UUID()
        dummyIsland.islandName = "Preview Island"
        dummyIsland.islandLocation = "Fictional Place"
        dummyIsland.country = "Imagination Land"
        dummyIsland.createdByUserId = "preview_user"
        dummyIsland.createdTimestamp = Date()
        dummyIsland.lastModifiedByUserId = "preview_user"
        dummyIsland.lastModifiedTimestamp = Date()
        dummyIsland.latitude = 34.0522
        dummyIsland.longitude = -118.2437
        dummyIsland.gymWebsite = URL(string: "https://example.com")

        // Add more dummy data (e.g., AppDayOfWeek, Reviews, MatTime)
        // if your preview views expect them to be present.
        // For example, a dummy AppDayOfWeek
        let dummyAppDayOfWeek = AppDayOfWeek(context: viewContext)
        dummyAppDayOfWeek.id = UUID() // Use the 'id' property for the UUID
        dummyAppDayOfWeek.day = DayOfWeek.monday.rawValue // Use 'day' property, assign rawValue String


        dummyAppDayOfWeek.pIsland = dummyIsland // Link to the dummy island using 'pIsland'

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    // MARK: - Unified Initializer (This should be the ONLY initializer)
    private init(inMemory: Bool = false) {
        self.firestoreManager = FirestoreManager.shared
        container = NSPersistentContainer(name: "Seas_3") // Use your actual data model name

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            // Ensure FirestoreManager can be truly "disabled" or mocked
            FirestoreManager.shared.disabled = true
        }

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Core Data Methods

    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        return try viewContext.fetch(request)
    }

    func create<T: NSManagedObject>(entityName: String) -> T? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: viewContext) else { return nil }
        return T(entity: entity, insertInto: viewContext)
    }

    func saveContext() async throws {
        // Ensure that any operation on viewContext (including checking hasChanges and saving)
        // is performed on the viewContext's designated queue.
        // For the main viewContext, this means the main thread.
        try await viewContext.perform {
            if self.viewContext.hasChanges { // Use self to refer to viewContext inside the closure
                do {
                    try self.viewContext.save()
                } catch {
                    // It's good practice to log or handle the error more gracefully here
                    // rather than just re-throwing in some cases.
                    print("Error saving viewContext: \(error)")
                    // Optionally, roll back changes if the save fails
                    self.viewContext.rollback()
                    throw error // Re-throw the error for the caller to handle
                }
            }
        }
    }

    // MARK: - Pirate Island Methods

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
        createdTimestamp: Date,
        lastModifiedByUserId: String,
        lastModifiedTimestamp: Date,
        latitude: Double,
        longitude: Double,
        gymWebsiteURL: URL?
    ) async throws -> PirateIsland {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", islandID.uuidString)

        if let existingIsland = try await fetch(fetchRequest).first {
            // Update existing island
            existingIsland.islandName = name
            existingIsland.islandLocation = location
            existingIsland.country = country
            Logger.logCreatedByIdEvent(createdByUserId: createdByUserId, fileName: "PersistenceController", functionName: "createOrUpdatePirateIsland")
            existingIsland.createdByUserId = createdByUserId
            existingIsland.createdTimestamp = createdTimestamp
            existingIsland.lastModifiedByUserId = lastModifiedByUserId
            existingIsland.lastModifiedTimestamp = lastModifiedTimestamp
            existingIsland.latitude = latitude
            existingIsland.longitude = longitude
            existingIsland.gymWebsite = gymWebsiteURL
            try await saveContext()
            return existingIsland
        } else {
            // Create new island
            let pirateIsland = PirateIsland(context: viewContext)
            pirateIsland.islandID = islandID
            pirateIsland.islandName = name
            pirateIsland.islandLocation = location
            pirateIsland.country = country
            Logger.logCreatedByIdEvent(createdByUserId: createdByUserId, fileName: "PersistenceController", functionName: "createOrUpdatePirateIsland")
            pirateIsland.createdByUserId = createdByUserId
            pirateIsland.createdTimestamp = createdTimestamp
            pirateIsland.lastModifiedByUserId = lastModifiedByUserId
            pirateIsland.lastModifiedTimestamp = lastModifiedTimestamp
            pirateIsland.latitude = latitude
            pirateIsland.longitude = longitude
            pirateIsland.gymWebsite = gymWebsiteURL
            try await saveContext()
            return pirateIsland
        }
    }

    func cachePirateIslandsFromFirestore() async throws {
        print("Fetching pirate islands from Firestore...")
        let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands)
        print("Fetched \(snapshot.count) pirate islands from Firestore")

        for document in snapshot {
            let islandID = document.documentID
            let name = document.get("name") as? String ?? ""
            let location = document.get("location") as? String ?? ""
            let country = document.get("country") as? String ?? ""
            let createdByUserId = document.get("createdByUserId") as? String ?? ""
            Logger.logCreatedByIdEvent(createdByUserId: createdByUserId, fileName: "PersistenceController", functionName: "cachePirateIslandsFromFirestore")
            let latitude = document.get("latitude") as? Double ?? 0
            let longitude = document.get("longitude") as? Double ?? 0
            let gymWebsiteURL = URL(string: document.get("gymWebsite") as? String ?? "")
            let createdTimestamp = document.get("createdTimestamp") as? Timestamp ?? Timestamp(date: Date())
            let lastModifiedByUserId = document.get("lastModifiedByUserId") as? String ?? ""
            let lastModifiedTimestamp = document.get("lastModifiedTimestamp") as? Timestamp ?? Timestamp(date: Date())

            _ = try await createOrUpdatePirateIsland(
                islandID: UUID(uuidString: islandID) ?? UUID(),
                name: name,
                location: location,
                country: country,
                createdByUserId: createdByUserId,
                createdTimestamp: createdTimestamp.dateValue(),
                lastModifiedByUserId: lastModifiedByUserId,
                lastModifiedTimestamp: lastModifiedTimestamp.dateValue(),
                latitude: latitude,
                longitude: longitude,
                gymWebsiteURL: gymWebsiteURL
            )

            print("Updated/created pirate island with ID: \(islandID)")
        }

        try await saveContext()
        print("Saved pirate islands to Core Data")
    }

    func fetchSingle(entityName: String) async throws -> NSManagedObject? {
        if entityName == "PirateIsland" {
            do {
                guard let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands).first else {
                    return nil
                }

                let islandEntity = NSEntityDescription.entity(forEntityName: "PirateIsland", in: container.viewContext)!
                let pirateIsland = PirateIsland(entity: islandEntity, insertInto: container.viewContext)

                let documentID = snapshot.documentID
                if let uuid = UUID(uuidString: documentID) {
                    pirateIsland.islandID = uuid
                } else {
                    pirateIsland.islandID = UUID()
                }

                pirateIsland.islandName = snapshot.get("islandName") as? String
                try await saveContext()
                return pirateIsland
            } catch {
                print("Error fetching pirate island from Firebase: \(error.localizedDescription)")
                throw error
            }
        }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.fetchLimit = 1

        do {
            return try viewContext.fetch(fetchRequest).first
        } catch {
            throw PersistenceError.fetchError(error)
        }
    }

    @MainActor
    func fetchLocalRecord(for firestoreUuidString: String, using managedObjectContext: NSManagedObjectContext) -> PirateIsland? {
        let normalizedUUIDString: String
        if let _ = UUID(uuidString: firestoreUuidString) {
            normalizedUUIDString = firestoreUuidString
        } else {
            let noHyphen = firestoreUuidString.replacingOccurrences(of: "-", with: "")
            guard let _ = UUID(uuidString: noHyphen) else {
                print("Invalid UUID format: \(firestoreUuidString)")
                return nil
            }
            normalizedUUIDString = noHyphen
        }

        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", normalizedUUIDString)
        fetchRequest.fetchLimit = 1

        do {
            let results = try managedObjectContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching record: \(error)")
            return nil
        }
    }

    func fetchLocalRecords(forCollection collectionName: String) async throws -> [String]? {
        return try await MainActor.run {
            switch collectionName {
            case "pirateIslands":
                return try fetchLocalRecords(forEntity: PirateIsland.self, keyPath: \.islandID)
            case "reviews":
                return try fetchLocalRecords(forEntity: Review.self, keyPath: \.reviewID)
            case "matTimes":
                return try fetchLocalRecords(forEntity: MatTime.self, keyPath: \.id)
            default:
                throw PersistenceError.invalidCollectionName(collectionName)
            }
        }
    }

    func fetchLocalRecord(forCollection collectionName: String, recordId: UUID) async throws -> NSManagedObject? {
        let entityNameMap = [
            "pirateIslands": "PirateIsland",
            "reviews": "Review",
            "matTimes": "MatTime",
            "appDayOfWeeks": "AppDayOfWeek"
        ]

        guard let entityName = entityNameMap[collectionName] else {
            throw PersistenceError.invalidCollectionName(collectionName)
        }

        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: viewContext) else {
            throw PersistenceError.entityNotFound(entityName)
        }

        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.entity = entity

        let primaryKeyMap = [
            "pirateIslands": "islandID",
            "reviews": "reviewID",
            "matTimes": "id",
            "appDayOfWeeks": "id"
        ]

        guard let primaryKey = primaryKeyMap[collectionName] else {
            throw PersistenceError.invalidCollectionName(collectionName)
        }

        fetchRequest.predicate = NSPredicate(format: "\(primaryKey) == %@", recordId.uuidString)
        fetchRequest.fetchLimit = 1

        let results = try viewContext.fetch(fetchRequest)
        return results.first
    }

    @MainActor
    func fetchLocalRecords<T: NSManagedObject>(forEntity entity: T.Type, keyPath: KeyPath<T, UUID>) throws -> [String] {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entity))
        let records = try viewContext.fetch(fetchRequest)
        return records.map { $0[keyPath: keyPath].uuidString }
    }

    @MainActor
    func fetchLocalRecords<T: NSManagedObject>(forEntity entity: T.Type, keyPath: KeyPath<T, UUID?>) throws -> [String] {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entity))
        let records = try viewContext.fetch(fetchRequest)
        return records.compactMap { $0[keyPath: keyPath]?.uuidString }
    }

    // MARK: - Firestore Sync Helpers

    private func getFirestoreCollection(for record: NSManagedObject) -> FirestoreManager.Collection? {
        switch record.entity.name {
        case "PirateIsland": return .pirateIslands
        case "Review": return .reviews
        case "MatTime": return .matTimes
        case "AppDayOfWeek": return .appDayOfWeeks
        default: return nil
        }
    }

    private func getDocumentID(for record: NSManagedObject) -> String? {
        switch record {
        case let island as PirateIsland: return island.islandID?.uuidString
        case let review as Review: return review.reviewID.uuidString
        case let matTime as MatTime: return matTime.id?.uuidString
        case let appDayOfWeek as AppDayOfWeek: return appDayOfWeek.id?.uuidString
        default:
            print("WARNING: Unknown entity type or missing ID property for \(record.entity.name ?? "unknown")")
            return nil
        }
    }

    func deleteRecord(record: NSManagedObject) async throws {
        viewContext.delete(record)
        try await saveContext()

        guard let documentID = getDocumentID(for: record),
              let collection = getFirestoreCollection(for: record) else {
            print("Could not determine Firestore collection or document ID for record of type \(record.entity.name ?? "unknown")")
            return
        }

        do {
            try await firestoreManager.deleteDocument(in: collection, id: documentID)
            print("✅ Successfully deleted \(record.entity.name ?? "record") with ID \(documentID) from Firestore.")
        } catch {
            print("❌ Error deleting from Firestore: \(error.localizedDescription)")
            throw PersistenceError.saveError(error)
        }
    }

    func editRecord(record: NSManagedObject, updates: [String: Any]) async throws {
        for (key, value) in updates {
            record.setValue(value, forKey: key)
        }
        try await saveContext()

        guard let documentID = getDocumentID(for: record),
              let collection = getFirestoreCollection(for: record) else {
            print("Could not determine Firestore collection or document ID for record of type \(record.entity.name ?? "unknown")")
            return
        }

        do {
            try await firestoreManager.updateDocument(in: collection, id: documentID, data: updates)
            print("✅ Successfully updated \(record.entity.name ?? "record") with ID \(documentID) in Firestore.")
        } catch {
            print("❌ Error updating Firestore: \(error.localizedDescription)")
            throw PersistenceError.saveError(error)
        }
    }

    // MARK: - Error Enum

    enum PersistenceError: Error, CustomStringConvertible {
        case fetchError(Error)
        case saveError(Error)
        case invalidCollectionName(String)
        case entityNotFound(String)
        case invalidUUID(String)
        case recordNotFound(String)
        case invalidRecordId(String)

        var description: String {
            switch self {
            case .fetchError(let error): return "Fetch error: \(error.localizedDescription)"
            case .saveError(let error): return "Save error: \(error.localizedDescription)"
            case .invalidCollectionName(let name): return "Invalid collection name: \(name)"
            case .entityNotFound(let entityName): return "Entity not found: \(entityName)"
            case .invalidUUID(let uuid): return "Invalid UUID: \(uuid)"
            case .recordNotFound(let id): return "Record not found: \(id)"
            case .invalidRecordId(let id): return "Invalid record ID: \(id)"
            }
        }
    }
}

// MARK: - Schedule Extensions

extension PersistenceController {
    func fetchSchedules(for predicate: NSPredicate) async throws -> [AppDayOfWeek] {
        // This is the crucial change:
        // 'await container.viewContext.perform' ensures the Core Data operation
        // runs on the queue associated with viewContext (which is the main queue).
        return try await container.viewContext.perform {
            let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
            fetchRequest.predicate = predicate

            do {
                let results = try self.container.viewContext.fetch(fetchRequest)
                return results
            } catch {
                // It's good to re-throw a more specific error or log it here as well
                throw PersistenceController.PersistenceError.fetchError(error)
            }
        }
    }
}


