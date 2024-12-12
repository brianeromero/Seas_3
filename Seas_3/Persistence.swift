
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
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        for _ in 0..<5 {
            let sampleIsland = PirateIsland(context: viewContext)
            sampleIsland.islandID = UUID()
            sampleIsland.islandName = "SAAAMMMPPPLLLEEEE Gym"
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
    
    // Firestore manager
    let firestoreManager: FirestoreManager
    
    // ViewContext for accessing Core Data
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    // Initializer
    convenience init(inMemory: Bool = false) {
        self.init()
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
    }
    
    private init() {
        self.firestoreManager = FirestoreManager.shared
        container = NSPersistentContainer(name: "Seas_3") // Use your Core Data model name
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
        let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands)
        
        for document in snapshot {
            guard let islandID = UUID(uuidString: document.documentID) else {
                print("Invalid UUID: \(document.documentID)")
                continue
            }
            
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
    
    // Sync Firestore data into Core Data
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
    
    // Fetch specific entity from Core Data or Firebase
    func fetchSingle(entityName: String) async throws -> NSManagedObject? {
        if entityName == "PirateIsland" {
            do {
                // Fetch from Firebase
                guard let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands).first else {
                    return nil
                }
                
                // Create a new Core Data object
                let islandEntity = NSEntityDescription.entity(forEntityName: "PirateIsland", in: container.viewContext)!
                let pirateIsland = PirateIsland(entity: islandEntity, insertInto: container.viewContext)
                
                // Get the document ID from the snapshot
                let documentID = snapshot.documentID
                if let uuid = UUID(uuidString: documentID) {
                    pirateIsland.islandID = uuid
                } else {
                    // Handle the case when documentID is not a valid UUID string
                    pirateIsland.islandID = UUID()
                }
                
                pirateIsland.islandName = snapshot.get("islandName") as? String
                // Map other attributes
                
                try await saveContext()
                return pirateIsland
            } catch {
                print("Error fetching pirate island from Firebase: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Fetch from Core Data
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.fetchLimit = 1

        do {
            return try viewContext.fetch(fetchRequest).first
        } catch {
            throw PersistenceError.fetchError(error)
        }
    }


    // Fetch a single PirateIsland from Firebase
    func fetchPirateIslandFromFirebase() async throws -> PirateIsland? {
        guard let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands).first else {
            return nil
        }
        
        let island = PirateIsland(context: viewContext)
        island.islandID = UUID() // Generate a new UUID if documentID is not a valid UUID
        island.islandName = snapshot.get("islandName") as? String
        
        return island
    }
    
    func fetchLocalRecord(for firestoreUuidString: String, using managedObjectContext: NSManagedObjectContext) -> PirateIsland? {
        // Attempt to convert recordId to UUID with hyphens
        guard let uuid = UUID(uuidString: firestoreUuidString) else {
            // Attempt to convert recordId to UUID without hyphens
            guard let uuidNoHyphens = UUID(uuidString: firestoreUuidString.replacingOccurrences(of: "-", with: "")) else {
                print("Invalid UUID format")
                return nil
            }
            
            let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuidNoHyphens as CVarArg)
            
            do {
                let results = try managedObjectContext.fetch(fetchRequest)
                return results.first
            } catch {
                print("Error fetching record: \(error)")
                return nil
            }
        }
        
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
        
        do {
            let results = try managedObjectContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching record: \(error)")
            return nil
        }
    }

    
    func fetchLocalRecords(forCollection collectionName: String) async throws -> [String]? {
        switch collectionName {
        case "pirateIslands":
            return try await fetchLocalRecords(forEntity: PirateIsland.self, keyPath: \.islandID)
        case "reviews":
            return try await fetchLocalRecords(forEntity: Review.self, keyPath: \.reviewID)
        case "matTimes":
            return try await fetchLocalRecords(forEntity: MatTime.self, keyPath: \.id)
        default:
            throw PersistenceError.invalidCollectionName(collectionName)
        }
    }
    
    func fetchLocalRecord(forCollection collectionName: String, recordId: UUID) async throws -> NSManagedObject? {
        print("Fetching local record for collection: \(collectionName) with recordId: \(recordId)")
        
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

    
    func fetchLocalRecords<T: NSManagedObject>(forEntity entity: T.Type, keyPath: KeyPath<T, UUID>) async throws -> [String] {
        do {
            let fetchRequest = entity.fetchRequest()
            let records = try viewContext.fetch(fetchRequest) as? [T] ?? []
            return records.map { $0[keyPath: keyPath].uuidString }
        } catch {
            throw PersistenceError.fetchError(error)
        }
    }
    
    func fetchLocalRecords<T: NSManagedObject>(forEntity entity: T.Type, keyPath: KeyPath<T, UUID?>) async throws -> [String] {
        do {
            let fetchRequest = entity.fetchRequest()
            let records = try viewContext.fetch(fetchRequest) as? [T] ?? []
            return records.compactMap { $0[keyPath: keyPath]?.uuidString }
        } catch {
            throw PersistenceError.fetchError(error)
        }
    }
    
    // Custom error enum
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
            case .fetchError(let error):
                return "Fetch error: \(error.localizedDescription)"
            case .saveError(let error):
                return "Save error: \(error.localizedDescription)"
            case .invalidCollectionName(let name):
                return "Invalid collection name: \(name)"
            case .entityNotFound(let entityName):
                return "Entity not found: \(entityName)"
            case .invalidUUID(let uuidString):
                return "Invalid UUID: \(uuidString)"
            case .recordNotFound(let recordId):
                return "Record not found: \(recordId)"
            case .invalidRecordId(let recordId):
                return "Invalid record ID: \(recordId)"


            }
        }
    }
    
    func deleteRecord(record: NSManagedObject) async throws {
        // Delete the record from Core Data
        viewContext.delete(record)
        try await saveContext()
        
        // Get the document ID from the record
        if let documentID = record.value(forKey: "id") as? String {
            do {
                // Delete the document from Firestore
                try await firestoreManager.deleteDocument(in: .pirateIslands, id: documentID)
            } catch {
                print("Error deleting document from Firestore: \(error.localizedDescription)")
            }
        } else {
            print("Document ID is missing or not a String")
        }
    }

    func editRecord(record: NSManagedObject, updates: [String: Any]) async throws {
        // Update the record with the given updates
        for (key, value) in updates {
            record.setValue(value, forKey: key)
        }
        try await saveContext()
        
        // Get the document ID from the record
        if let documentID = record.value(forKey: "id") as? String {
            do {
                // Update the document in Firestore
                try await firestoreManager.updateDocument(in: .pirateIslands, id: documentID, data: updates)
            } catch {
                print("Error updating document in Firestore: \(error.localizedDescription)")
            }
        } else {
            print("Document ID is missing or not a String")
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
            throw PersistenceError.fetchError(error)
        }
    }
}
