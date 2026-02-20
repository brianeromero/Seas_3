// Persistence.swift
// Mat_Finder
// Created by Brian Romero on 6/24/24.

@preconcurrency
import CoreData
import Combine
import Foundation
import UIKit
import FirebaseFirestore
import FirebaseCore
import FirebaseAuth

@MainActor
final class PersistenceController: ObservableObject {

    // MARK: - Singleton Instance
    static let shared = PersistenceController()

    // MARK: - Core Data & Firestore
    let container: NSPersistentContainer
    let firestoreManager: FirestoreManager

    var viewContext: NSManagedObjectContext { container.viewContext }

    
    // MARK: - Preview Provider
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        let dummyIsland = PirateIsland(context: viewContext)
        dummyIsland.islandID = UUID().uuidString
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

        do { try viewContext.save() }
        catch { fatalError("Preview save failed: \(error)") }

        return result
    }()

    
    // MARK: - Initializer
    private init(inMemory: Bool = false) {
        self.firestoreManager = FirestoreManager.shared
        container = NSPersistentContainer(name: "Mat_Finder")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("❌ No persistent store description found.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            FirestoreManager.shared.disabled = true
        }

        // 🔥 LIGHTWEIGHT MIGRATION ENABLED
        description.setOption(true as NSNumber,
                              forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber,
                              forKey: NSInferMappingModelAutomaticallyOption)

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                print("🔥 Persistent Store Load Error:")
                print(error)
                print(error.userInfo)
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("✅ Persistent Store Loaded: \(description.url?.absoluteString ?? "unknown")")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        container.viewContext.perform {
            print("✅ ViewContext running on main thread: \(Thread.isMainThread)")
        }
    }
    
    // MARK: - Core Data Methods
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        try viewContext.fetch(request)
    }

    func create<T: NSManagedObject>(entityName: String) -> T? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: viewContext)
        else { return nil }
        return T(entity: entity, insertInto: viewContext)
    }


    // MARK: - Save Context
    func saveContext() async throws {
        guard viewContext.hasChanges else {
            print("💤 No Core Data changes to save")
            return
        }

        do {
            try viewContext.save()
            print("💾 Core Data save successful")
        } catch {
            viewContext.rollback()
            print("❌ Core Data save failed: \(error)")
            throw error
        }
    }

    
    // MARK: - PirateIsland CRUD
    func fetchAllPirateIslands() async throws -> [PirateIsland] {
        let request: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        return try await fetch(request)
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

        let request: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        request.predicate = NSPredicate(format: "islandID == %@", islandID.uuidString)
        
        if let existing = try await fetch(request).first {
            existing.islandName = name
            existing.islandLocation = location
            existing.country = country
            existing.createdByUserId = createdByUserId
            existing.createdTimestamp = createdTimestamp
            existing.lastModifiedByUserId = lastModifiedByUserId
            existing.lastModifiedTimestamp = lastModifiedTimestamp
            existing.latitude = latitude
            existing.longitude = longitude
            existing.gymWebsite = gymWebsiteURL
            try await saveContext()
            return existing
        } else {
            let newIsland = PirateIsland(context: viewContext)
            newIsland.islandID = islandID.uuidString
            newIsland.islandName = name
            newIsland.islandLocation = location
            newIsland.country = country
            newIsland.createdByUserId = createdByUserId
            newIsland.createdTimestamp = createdTimestamp
            newIsland.lastModifiedByUserId = lastModifiedByUserId
            newIsland.lastModifiedTimestamp = lastModifiedTimestamp
            newIsland.latitude = latitude
            newIsland.longitude = longitude
            newIsland.gymWebsite = gymWebsiteURL
            try await saveContext()
            return newIsland
        }
    }
    

    func cachePirateIslandsFromFirestore() async throws {
        let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands)

        for document in snapshot {
            let islandID = UUID(uuidString: document.documentID) ?? UUID()
            let name = document.get("name") as? String ?? ""
            let location = document.get("location") as? String ?? ""
            let country = document.get("country") as? String ?? ""
            let createdByUserId = document.get("createdByUserId") as? String ?? ""
            let createdTimestamp = (document.get("createdTimestamp") as? Timestamp)?.dateValue() ?? Date()
            let lastModifiedByUserId = document.get("lastModifiedByUserId") as? String ?? ""
            let lastModifiedTimestamp = (document.get("lastModifiedTimestamp") as? Timestamp)?.dateValue() ?? Date()
            let latitude = document.get("latitude") as? Double ?? 0
            let longitude = document.get("longitude") as? Double ?? 0

            let websiteString = document.get("gymWebsite") as? String
            let gymWebsiteURL = websiteString.flatMap { URL(string: $0) }

            _ = try await createOrUpdatePirateIsland(
                islandID: islandID,
                name: name,
                location: location,
                country: country,
                createdByUserId: createdByUserId,
                createdTimestamp: createdTimestamp,
                lastModifiedByUserId: lastModifiedByUserId,
                lastModifiedTimestamp: lastModifiedTimestamp,
                latitude: latitude,
                longitude: longitude,
                gymWebsiteURL: gymWebsiteURL
            )
        }
    }
    
    func fetchSingle(entityName: String) async throws -> NSManagedObject? {
        if entityName == "PirateIsland" {
            guard let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands).first else { return nil }
            let island = PirateIsland(context: viewContext)
            island.islandID = snapshot.documentID  // ✅ Assign string directly
            island.islandName = snapshot.get("islandName") as? String
            try await saveContext()
            return island
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }

    
    // MARK: - Local Fetch Helpers
    
    // MARK: - Local Fetch Helpers (String ID version for PirateIsland)
    func fetchLocalRecord(forCollection collectionName: String, recordId: String) throws -> NSManagedObject? {
        guard collectionName == "pirateIslands" else { return nil }

        let request = NSFetchRequest<PirateIsland>(entityName: "PirateIsland")
        request.predicate = NSPredicate(format: "islandID == %@", recordId)
        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }
    
    func fetchLocalRecord(forCollection collectionName: String, recordId: UUID) throws -> NSManagedObject? {
        let entityMap = [
            "reviews": "Review",
            "matTimes": "MatTime",
            "appDayOfWeeks": "AppDayOfWeek"
        ]
        guard let entityName = entityMap[collectionName] else { return nil }
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)

        // Normalize both forms of the ID
        let idString = recordId.uuidString
        let idNoHyphen = idString.replacingOccurrences(of: "-", with: "")

        switch collectionName {
        case "reviews":
            request.predicate = NSPredicate(format: "reviewID == %@ OR reviewID == %@", idString, idNoHyphen)
        case "matTimes":
            request.predicate = NSPredicate(format: "id == %@ OR id == %@", idString, idNoHyphen)
        case "appDayOfWeeks":
            request.predicate = NSPredicate(format: "appDayOfWeekID == %@ OR appDayOfWeekID == %@", idString, idNoHyphen)
        default:
            return nil
        }

        request.fetchLimit = 1
        return try viewContext.fetch(request).first
    }

    // MARK: - Generic Record Fetchers
    // For entities where the UUID is optional (UUID?)
    func fetchLocalRecords<T: NSManagedObject>(
        forEntity entity: T.Type,
        keyPath: KeyPath<T, UUID?>
    ) throws -> [String] {
        let request = NSFetchRequest<T>(entityName: String(describing: entity))
        return try viewContext.fetch(request).compactMap { $0[keyPath: keyPath]?.uuidString }
    }

    // For entities where the UUID is non-optional (UUID)
    func fetchLocalRecords<T: NSManagedObject>(
        forEntity entity: T.Type,
        keyPath: KeyPath<T, UUID>
    ) throws -> [String] {
        let request = NSFetchRequest<T>(entityName: String(describing: entity))
        return try viewContext.fetch(request).map { $0[keyPath: keyPath].uuidString }
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
        case let island as PirateIsland: return island.islandID
        case let review as Review: return review.reviewID.uuidString
        case let matTime as MatTime: return matTime.id?.uuidString
        case let appDay as AppDayOfWeek: return appDay.id?.uuidString
        default: return nil
        }
    }
    
    // MARK: - Delete/Edit Records
    func deleteRecord(record: NSManagedObject) async throws {
        viewContext.delete(record)
        try await saveContext()
        if let docID = getDocumentID(for: record),
           let collection = getFirestoreCollection(for: record) {
            try await firestoreManager.deleteDocument(in: collection, id: docID)
        }
    }
    
    func editRecord(record: NSManagedObject, updates: [String: Any]) async throws {
        for (key, value) in updates { record.setValue(value, forKey: key) }
        try await saveContext()
        if let docID = getDocumentID(for: record),
           let collection = getFirestoreCollection(for: record) {
            try await firestoreManager.updateDocument(in: collection, id: docID, data: updates)
        }
    }
    
    // MARK: - Error Enum
    enum PersistenceError: Error, CustomStringConvertible {
        case fetchError(Error), saveError(Error), invalidCollectionName(String),
             entityNotFound(String), invalidUUID(String), recordNotFound(String),
             invalidRecordId(String)
        
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
    @MainActor
    func fetchSchedules(for predicate: NSPredicate) throws -> [AppDayOfWeek] {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = predicate
        return try viewContext.fetch(request)
    }
}


extension PersistenceController {
    
    func fetchLocalRecords<T: NSManagedObject>(
        forEntity entity: T.Type,
        keyPath: KeyPath<T, String?>
    ) throws -> [String] {
        let request = NSFetchRequest<T>(entityName: String(describing: entity))
        return try viewContext.fetch(request).compactMap { $0[keyPath: keyPath] }
    }
    
    
    func fetchLocalRecords(forCollection collectionName: String) async throws -> [String]? {
        switch collectionName {
        case "pirateIslands":
            // ✅ Correct property name: islandID (UUID?)
            return try fetchLocalRecords(forEntity: PirateIsland.self, keyPath: \PirateIsland.islandID)
        case "reviews":
            // ✅ Non-optional UUID, will use the second overload automatically
            return try fetchLocalRecords(forEntity: Review.self, keyPath: \Review.reviewID)
        case "AppDayOfWeek":
            return try fetchLocalRecords(forEntity: AppDayOfWeek.self, keyPath: \AppDayOfWeek.id)
        case "MatTime":
            return try fetchLocalRecords(forEntity: MatTime.self, keyPath: \MatTime.id)
        default:
            print("⚠️ Unknown collection: \(collectionName)")
            return nil
        }
    }

    /// Ensures Core Data background merges complete before dependent downloads begin
    func waitForBackgroundSaves() async throws {
        await container.viewContext.perform {
            // Forces all background context changes to merge
            self.container.viewContext.refreshAllObjects()
        }
    }
}
