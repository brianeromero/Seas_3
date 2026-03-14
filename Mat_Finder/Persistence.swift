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

    private let matTimeMigrationKey = "MatTimeMigrationComplete"
    
    // MARK: - Initializer

    private init(inMemory: Bool = false) {
        
        firestoreManager = FirestoreManager.shared
        
        container = NSPersistentContainer(name: "Mat_Finder")
        
        guard let description =
                container.persistentStoreDescriptions.first
        else {
            
            fatalError("❌ No persistent store description found.")
        }
        
        
        if inMemory {
            
            description.url =
            URL(fileURLWithPath: "/dev/null")
            
            FirestoreManager.shared.disabled = true
        }
        
        
        // ✅ Lightweight migration (Cloud-safe fix)
        
        description.shouldMigrateStoreAutomatically = true
        
        description.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores { [weak self] description, error in

            guard let self else { return }

            if let error {
                fatalError("❌ Persistent store load error: \(error)")
            }

            print("✅ Persistent Store Loaded:",
                  description.url?.absoluteString ?? "")

            print("📦 STORE URL:",
                  description.url?.path ?? "nil")

            if let path = description.url?.path {

                print("📦 STORE EXISTS:",
                      FileManager.default.fileExists(atPath: path))
            }

            let viewContext = self.container.viewContext

            // 🚀 PERFORMANCE OPTIMIZATIONS (SET FIRST)

            viewContext.mergePolicy =
                NSMergeByPropertyObjectTrumpMergePolicy

            viewContext.undoManager = nil

            viewContext.shouldDeleteInaccessibleFaults = true

            viewContext.automaticallyMergesChangesFromParent = true

            viewContext.transactionAuthor = "viewContext"

            // DEBUG ONLY — force migration to run again
            UserDefaults.standard.removeObject(forKey: "MatTimeMigrationComplete")

            // ⭐ RUN MIGRATION AFTER CONTEXT IS CONFIGURED
            self.migrateMatTimeIfNeeded(context: viewContext)
            
            viewContext.perform {

                viewContext.processPendingChanges()

                print("✅ Core Data fully optimized")
            }
            
            // =====================================================
            // ✅ APPLE-LEVEL AUTO MERGE FIX (ADD THIS HERE)
            // =====================================================
            
            NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: nil,
                queue: nil
            ) { [weak self] notification in

                guard let self else { return }

                // Extract context safely OUTSIDE Task
                guard let savedContext =
                    notification.object as? NSManagedObjectContext
                else { return }

                // Ignore viewContext saves
                if savedContext === self.container.viewContext {
                    return
                }

                // Hop to MainActor safely
                Task { @MainActor [weak self] in

                    guard let self else { return }

                    self.viewContext.mergeChanges(
                        fromContextDidSave: notification
                    )
                }
            }
        }
    }

    // MARK: - SAFE VIEW CONTEXT SAVE

    func saveViewContext() {

        let context = container.viewContext

        guard context.hasChanges else { return }

        context.performAndWait {

            do {

                try context.save()

            }
            catch {

                context.rollback()

                print(
                    "❌ viewContext save error:",
                    error
                )
            }
        }
    }
    
    func migrateMatTimeIfNeeded(context: NSManagedObjectContext) {

        let defaults = UserDefaults.standard

        guard !defaults.bool(forKey: matTimeMigrationKey) else {
            print("⏭️ MatTime migration already completed")
            return
        }

        print("🔄 Running MatTime migration...")

        let request: NSFetchRequest<MatTime> = MatTime.fetchRequest()

        do {

            let mats = try context.fetch(request)

            var firestoreUpdates: [(id: String, discipline: String, style: String)] = []

            let validDisciplines: Set<String> = [
                "bjjGi","bjjNoGi","mma","wrestling","judo","striking","mobility"
            ]

            let validStyles: Set<String> = Set(Style.allCases.map { $0.rawValue })

            for mat in mats {

                var didChange = false

                // ------------------------------------------------
                // MIGRATE DISCIPLINE (REQUIRED)
                // ------------------------------------------------

                if mat.discipline?.isEmpty ?? true ||
                   !validDisciplines.contains(mat.discipline!) {

                    if mat.gi {
                        mat.discipline = "bjjGi"
                    }
                    else if mat.noGi {
                        mat.discipline = "bjjNoGi"
                    }
                    else {
                        mat.discipline = "bjjGi"   // safe fallback
                    }

                    didChange = true
                }

                // ------------------------------------------------
                // MIGRATE STYLE
                // ------------------------------------------------

                if mat.style?.isEmpty ?? true ||
                   !(mat.style.map { validStyles.contains($0) } ?? false) {

                    if mat.openMat {
                        mat.style = "openMat"
                    } else {
                        mat.style = "fundamentals"
                    }

                    didChange = true
                }

                // ------------------------------------------------
                // QUEUE FIRESTORE UPDATE (ONLY IF CHANGED)
                // ------------------------------------------------

                if didChange, let id = mat.id?.uuidString {

                    firestoreUpdates.append((
                        id: id,
                        discipline: mat.discipline ?? "bjjGi",
                        style: mat.style ?? "fundamentals"
                    ))
                }
            }

            if context.hasChanges {
                try context.save()
            }

            defaults.set(true, forKey: matTimeMigrationKey)

            print("✅ MatTime migration complete")

            Task.detached(priority: .background) {
                
                let firestore = Firestore.firestore()

                for update in firestoreUpdates {

                    try? await firestore
                        .collection("MatTime")
                        .document(update.id)
                        .setData([
                            "discipline": update.discipline,
                            "style": update.style
                        ], merge: true)
                }

                print("🔥 Firestore migration sync complete")
            }

        } catch {

            print("❌ MatTime migration failed:", error)
        }
    }

    // MARK: - Background Context

    func newBackgroundContext() -> NSManagedObjectContext {

        let context =
            container.newBackgroundContext()

        // ✅ DO NOT SET PARENT
        // container already manages hierarchy safely

        context.mergePolicy =
            NSMergeByPropertyObjectTrumpMergePolicy

        context.undoManager = nil

        context.transactionAuthor = "background"

        context.automaticallyMergesChangesFromParent = true
        
        return context
    }



    // MARK: - Firestore Context
    func newFirestoreContext() -> NSManagedObjectContext {

        let context = container.newBackgroundContext()

        // ✅ Name (great for debugging)
        context.name = "firestoreContext"

        // ✅ CRITICAL — prevents duplicates and resolves conflicts
        context.mergePolicy =
        NSMergeByPropertyObjectTrumpMergePolicy

        // ✅ Apple performance optimization
        context.undoManager = nil

        // ✅ CRITICAL FIX — must be TRUE
        context.automaticallyMergesChangesFromParent = true

        // ✅ Prevent sync loops
        context.transactionAuthor = "firestore"

        return context
    }

    // MARK: - Save (MainActor Safe)

    func saveContext() async throws {

        try await MainActor.run {

            guard self.viewContext.hasChanges else { return }

            self.viewContext.processPendingChanges()

            try self.viewContext.save()

            print("💾 Core Data save successful")
        }
    }



    // MARK: - Wait for background saves

    func waitForBackgroundSaves() async {

        await MainActor.run {

            self.saveViewContext()

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

            var didChange = false

            if existing.islandName != name {
                existing.islandName = name
                didChange = true
            }

            if existing.islandLocation != location {
                existing.islandLocation = location
                didChange = true
            }

            if existing.country != country {
                existing.country = country
                didChange = true
            }

            if existing.createdByUserId != createdByUserId {
                existing.createdByUserId = createdByUserId
                didChange = true
            }

            if existing.createdTimestamp != createdTimestamp {
                existing.createdTimestamp = createdTimestamp
                didChange = true
            }

            if existing.lastModifiedByUserId != lastModifiedByUserId {
                existing.lastModifiedByUserId = lastModifiedByUserId
                didChange = true
            }

            if existing.lastModifiedTimestamp != lastModifiedTimestamp {
                existing.lastModifiedTimestamp = lastModifiedTimestamp
                didChange = true
            }

            if existing.latitude != latitude {
                existing.latitude = latitude
                didChange = true
            }

            if existing.longitude != longitude {
                existing.longitude = longitude
                didChange = true
            }

            if existing.gymWebsite != gymWebsiteURL {
                existing.gymWebsite = gymWebsiteURL
                didChange = true
            }

            if didChange {
                try await saveContext()
                print("💾 Updated PirateIsland \(islandID)")
            } else {
                print("⏭️ No changes — skipping save \(islandID)")
            }

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

            guard let snapshot = try await firestoreManager.getDocuments(in: .pirateIslands).first else {
                return nil
            }

            let id = snapshot.documentID

            let request: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
            request.predicate = NSPredicate(format: "islandID == %@", id)
            request.fetchLimit = 1

            if let existing = try viewContext.fetch(request).first {
                return existing
            }

            let island = PirateIsland(context: viewContext)
            island.islandID = id
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
        case let appDay as AppDayOfWeek:
            return appDay.appDayOfWeekID   // ✅ CORRECT
        default: return nil
        }
    }
    
    // MARK: - Delete Local Record (Firestore authoritative)
    // MARK: - Delete Local Record (Firestore authoritative)
    func deleteLocalRecord(
        forCollection collectionName: String,
        recordId: String
    ) async {

        // ✅ FIX 1: USE firestoreContext (NOT backgroundContext)
        let context = newFirestoreContext()

        await context.perform {

            let entityName: String

            switch collectionName {

            case "pirateIslands":
                entityName = "PirateIsland"

            case "reviews":
                entityName = "Review"

            case "AppDayOfWeek":
                entityName = "AppDayOfWeek"

            case "MatTime":
                entityName = "MatTime"

            default:
                return
            }

            let fetchRequest =
            NSFetchRequest<NSManagedObject>(
                entityName: entityName
            )

            switch collectionName {

            case "pirateIslands":

                fetchRequest.predicate =
                NSPredicate(
                    format: "islandID == %@",
                    recordId
                )


            case "AppDayOfWeek":

                fetchRequest.predicate =
                NSPredicate(
                    format: "appDayOfWeekID == %@",
                    recordId
                )


            case "MatTime":

                guard let uuid =
                    UUID(uuidString: recordId)
                else { return }

                fetchRequest.predicate =
                NSPredicate(
                    format: "id == %@",
                    uuid as CVarArg
                )


            case "reviews":

                guard let uuid =
                    UUID(uuidString: recordId)
                else { return }

                fetchRequest.predicate =
                NSPredicate(
                    format: "reviewID == %@",
                    uuid as CVarArg
                )

            default:
                return
            }

            fetchRequest.fetchLimit = 1


            do {

                if let object =
                    try context.fetch(fetchRequest).first {

                    context.delete(object)

                    context.processPendingChanges()

                    try context.save()


                    // ✅ FIX 2: CRITICAL REFRESH PIPELINE

                    context.refreshAllObjects()

                    context.reset()

                    if let parent = context.parent {

                        parent.performAndWait {

                            parent.refreshAllObjects()

                        }
                    }


                    print(
                        "🗑️ Core Data deleted \(collectionName) \(recordId)"
                    )
                }

            }
            catch {

                context.rollback()

                print(
                    "❌ Core Data delete error:",
                    error
                )
            }
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

        let context = newFirestoreContext()

        return try await context.perform {

            switch collectionName {

            case "pirateIslands":

                let request =
                    NSFetchRequest<PirateIsland>(
                        entityName: "PirateIsland"
                    )

                request.returnsObjectsAsFaults = false
                request.includesPropertyValues = true

                return try context.fetch(request)
                    .compactMap { $0.islandID }


            case "reviews":

                let request =
                    NSFetchRequest<Review>(
                        entityName: "Review"
                    )

                request.returnsObjectsAsFaults = false
                request.includesPropertyValues = true

                return try context.fetch(request)
                    .map { $0.reviewID.uuidString }


            case "AppDayOfWeek":

                let request =
                    NSFetchRequest<AppDayOfWeek>(
                        entityName: "AppDayOfWeek"
                    )

                request.returnsObjectsAsFaults = false
                request.includesPropertyValues = true

                return try context.fetch(request)
                    .compactMap { $0.appDayOfWeekID }


            case "MatTime":

                let request =
                    NSFetchRequest<MatTime>(
                        entityName: "MatTime"
                    )

                request.returnsObjectsAsFaults = false
                request.includesPropertyValues = true

                return try context.fetch(request)
                    .compactMap { $0.id?.uuidString }


            default:

                return nil
            }
        }
    }
}
