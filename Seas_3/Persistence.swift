// Persistence.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import Combine
import Foundation
import CoreData
import UIKit
import FirebaseFirestore
import Firebase

// Notification Name extension
extension Notification.Name {
    static let contextSaved = Notification.Name("contextSaved")
}

public class PersistenceController: ObservableObject {
    // Shared instance
    public static let shared = try! PersistenceController(inMemory: false)

    // Firestore instance
    let db: Firestore
    
    // Container
    public let container: NSPersistentContainer

    // View context
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    // Initialize with error handling
    public init(inMemory: Bool = false) throws {
        FirebaseApp.configure()
        self.db = Firestore.firestore()

        container = NSPersistentContainer(name: "Seas_3")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        var loadError: Error?
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                loadError = error
            }
        }
        
        if let error = loadError {
            throw PersistenceError.loadError(error)
        }
        
        viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - General Persistence Methods

    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        if T.self == PirateIsland.self {
            try await cachePirateIslandsFromFirestore()
        }
        return try viewContext.fetch(request)
    }
    
    func create<T: NSManagedObject>(entityName: String) -> T? {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: viewContext) else {
            return nil
        }
        return T(entity: entity, insertInto: viewContext)
    }

    func saveContext() async throws {
        if viewContext.hasChanges {
            try viewContext.save()
            try await db.collection("contexts").document("latest").setData(["timestamp": Date()])
            NotificationCenter.default.post(name: .contextSaved, object: nil)
        }
    }

    // MARK: - Entity-Specific Methods

    func fetchSchedules(for predicate: NSPredicate) async throws -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        return try await fetch(fetchRequest)
    }

    func fetchAllPirateIslands() async throws -> [PirateIsland] {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        return try await fetch(fetchRequest)
    }

    func fetchLastPirateIsland() async throws -> PirateIsland? {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: false)]
        fetchRequest.fetchLimit = 1
        let results = try await fetch(fetchRequest)
        return results.first
    }

    // MARK: - UserInfo Helper Methods

    func fetchUser(byUserName userName: String) throws -> UserInfo? {
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userName == %@", userName)
        let results = try viewContext.fetch(fetchRequest)
        return results.first
    }

    func updateUserInfo(email: String, userName: String, name: String, belt: String?) async throws {
        try await db.collection("users").document(userName).setData(["email": email, "name": name, "belt": belt ?? ""])
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        if let userInfo = try await fetch(fetchRequest).first {
            userInfo.email = email
            userInfo.userName = userName
            userInfo.name = name
            userInfo.belt = belt
            try await saveContext()
        } else {
            print("No user profile found.")
        }
    }

    // MARK: - Pirate Island Helper Methods

    func fetchAppDayOfWeekForIslandAndDay(for island: PirateIsland, day: DayOfWeek) async throws -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        return try await fetch(fetchRequest)
    }


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
                let uuidString = "\(island.id)"
                pirateIsland.islandID = UUID(uuidString: uuidString)
                pirateIsland.islandName = island.islandName
                // Map other attributes
                try await saveContext()
                return pirateIsland
            }
        }
        
        return nil
    }

    private func fetchPirateIslandFromFirebase() async throws -> PirateIsland? {
        let snapshot = try await db.collection("pirateIslands").limit(to: 1).getDocuments()
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        let island = PirateIsland(context: viewContext)
        island.islandID = UUID(uuidString: document.documentID)
        island.islandName = document.get("islandName") as? String
        return island
    }

    // Cache pirate islands from Firestore
    func cachePirateIslandsFromFirestore() async throws {
        do {
            let snapshot = try await db.collection("pirateIslands").getDocuments()
            let _: [PirateIsland] = snapshot.documents.compactMap { document in
                let pirateIsland = PirateIsland(context: viewContext)
                pirateIsland.islandID = UUID(uuidString: document.documentID)
                pirateIsland.islandName = document.get("islandName") as? String ?? ""
                // Map other attributes
                return pirateIsland
            }
            try await saveContext()
        } catch {
            throw PersistenceError.firestoreError(error)
        }
    }

    // MARK: - Preview Persistence Controller

    static var preview: PersistenceController = {
        let result = try! PersistenceController(inMemory: true)
        let viewContext = result.viewContext

        for _ in 0..<10 {
            let newIsland = PirateIsland(context: viewContext)
            newIsland.islandID = UUID()
            newIsland.islandName = "Preview Gym"
            newIsland.latitude = 37.7749
            newIsland.longitude = -122.4194
            newIsland.createdTimestamp = Date()
            newIsland.islandLocation = "San Francisco, CA"
            // Set other required attributes as needed
        }

        try! viewContext.save()
        return result
    }()

    // Custom error enum
    enum PersistenceError: Error {
        case fetchError(Error)
        case saveError(Error)
        case firestoreError(Error)
        case loadError(Error)
    }
    }

    extension PirateIsland {
        var uuidID: UUID? {
            return islandID
        }
    }
