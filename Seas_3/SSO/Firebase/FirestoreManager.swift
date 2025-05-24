//
//  FirestoreManager.swift
//  Seas_3
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

public class FirestoreManager {
    public static let shared = FirestoreManager()

    var disabled: Bool = false
    
    private let db: Firestore
    
    private init() {
        self.db = Firestore.firestore()
    }
    
    // MARK: - User Management

    // Also add the disabled check in other methods that interact with Firestore
    func saveIslandToFirestore(
        island: PirateIsland,
        selectedCountry: Country,
        createdByUser: User // <- new parameter
    ) async throws {
        if disabled { return }
        print("Saving island to Firestore: \(island.safeIslandName)")

        guard let islandName = island.islandName, !islandName.isEmpty,
              let islandLocation = island.islandLocation, !islandLocation.isEmpty else {
            print("Invalid data: Island name or location is missing")
            return
        }

        // Convert UUID to String explicitly for Firestore (assuming Firestore expects a String)
        let islandIDString = (island.islandID)?.uuidString ?? UUID().uuidString
        let createdByUserIDString = createdByUser.id

        let islandRef = db.collection("pirateIslands").document(islandIDString)

        let islandData: [String: Any] = [
            "id": islandIDString, // Use the String version of islandID
            "name": island.safeIslandName,
            "location": island.safeIslandLocation,
            "country": selectedCountry.name.common,
            "createdByUserId": island.createdByUserId ?? "Unknown User",
            "createdBy": [
                "id": createdByUserIDString, // Use the String version of createdByUser.id
                "name": createdByUser.userName,
                "email": createdByUser.email
            ],
            "createdTimestamp": island.createdTimestamp ?? Date(),
            "lastModifiedByUserId": island.lastModifiedByUserId ?? "",
            "lastModifiedTimestamp": island.lastModifiedTimestamp ?? Date(),
            "latitude": island.latitude,
            "longitude": island.longitude,
            "gymWebsite": island.gymWebsite?.absoluteString ?? ""
        ]

        try await islandRef.setData(islandData, merge: true)
        print("Island saved successfully to Firestore")
    }


    // MARK: - Collection Management
    enum Collection: String {
        case appDayOfWeeks, matTimes, pirateIslands, reviews, userInfos
    }
    
    func updatePirateIsland(id: String, data: [String: Any]) async throws {
        if disabled { return }
        print("Updating pirate island with id: \(id)")
        try await updateDocument(in: .pirateIslands, id: id, data: data)
        print("Pirate island updated successfully")
    }

    func createAppDayOfWeek(data: [String: Any]) async throws {
        if disabled { return }
        print("Creating app day of week")
        try await createDocument(in: .appDayOfWeeks, data: data)
        print("App day of week created successfully")
    }

    // MARK: - Generic Firestore Operations
    private func setDocument(in collection: Collection, id: String, data: [String: Any]) async throws {
        print("Setting document in collection: \(collection.rawValue) with id: \(id)")
        try await db.collection(collection.rawValue).document(id).setData(data)
        print("Document set successfully")
    }

    internal func createDocument(in collection: Collection, data: [String: Any]) async throws {
        if disabled { return }
        print("Creating document in collection: \(collection.rawValue)")
        try await db.collection(collection.rawValue).document().setData(data)
        print("Document created successfully")
    }

    internal func updateDocument(in collection: Collection, id: String, data: [String: Any]) async throws {
        if disabled { return }
        print("Updating document in collection: \(collection.rawValue) with id: \(id)")
        try await db.collection(collection.rawValue).document(id).setData(data, merge: false)
        print("Document updated successfully")
    }
    
    internal func deleteDocument(in collection: Collection, id: String) async throws {
        if disabled { return }
        print("Deleting document in collection: \(collection.rawValue) with id: \(id)")
        try await db.collection(collection.rawValue).document(id).delete()
        print("Document deleted successfully")
    }

    internal func getDocuments(in collection: Collection) async throws -> [QueryDocumentSnapshot] {
        if disabled { return [] }
        print("Getting documents in collection: \(collection.rawValue)")
        let snapshot = try await db.collection(collection.rawValue).getDocuments()
        print("Documents retrieved successfully")
        return snapshot.documents
    }


    // MARK: - Specific Functions for Collections
    func getAppDayOfWeeks() async throws -> [QueryDocumentSnapshot] {
        print("Getting app day of weeks")
        return try await getDocuments(in: .appDayOfWeeks)
    }

    func getPirateIsland(for id: String) async throws -> QueryDocumentSnapshot? {
        print("Getting pirate island with id: \(id)")
        let documents = try await getDocuments(in: .pirateIslands)
        print("Pirate island retrieved successfully")
        return documents.first { $0.documentID == id }
    }
    
    func getReviews(for pirateIslandID: String) async throws -> [QueryDocumentSnapshot] {
        print("Getting reviews for pirate island with id: \(pirateIslandID)")
        let documents = try await getDocuments(in: .reviews)
        print("Reviews retrieved successfully")
        return documents.filter { $0.get("pirateIslandID") as? String == pirateIslandID }
    }
    
    // MARK: - Firestore Error Handling
    enum FirestoreError: Error {
        case documentNotFound, invalidData, unknownError
        
        var localizedDescription: String {
            switch self {
            case .documentNotFound: return "Document not found"
            case .invalidData: return "Invalid data"
            case .unknownError: return "Unknown error"
            }
        }
    }
    
    // MARK: - Real-Time Updates
    func listenForChanges(in collection: Collection, completion: @escaping ([QueryDocumentSnapshot]?) -> Void) {
        if disabled { return }
        print("Listening for changes in collection: \(collection.rawValue)")
        db.collection(collection.rawValue).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening for changes: \(error.localizedDescription)")
                completion(nil)
            } else {
                print("Changes detected in collection: \(collection.rawValue)")
                completion(snapshot?.documents)
            }
        }
    }

    // MARK: - Advanced Operations
    func performBatchOperations(operations: [(operation: FirestoreBatchOperation, collection: Collection, data: [String: Any])], completion: @escaping (Error?) -> Void) {
        print("Performing batch operations")
        let batch = db.batch()
        for operation in operations {
            let documentRef = db.collection(operation.collection.rawValue).document()
            switch operation.operation {
            case .create:
                batch.setData(operation.data, forDocument: documentRef)
            case .update:
                batch.updateData(operation.data, forDocument: documentRef)
            case .delete:
                batch.deleteDocument(documentRef)
            }
        }
        batch.commit { error in
            if let error = error {
                print("Error performing batch operations: \(error.localizedDescription)")
            } else {
                print("Batch operations performed successfully")
            }
            completion(error)
        }
    }

    enum FirestoreBatchOperation {
        case create, update, delete
    }

    func getPaginatedDocuments(in collection: Collection, lastDocument: QueryDocumentSnapshot?, limit: Int, completion: @escaping ([QueryDocumentSnapshot]?, Error?) -> Void) {
        if disabled { completion([], nil); return }
        print("Getting paginated documents in collection: \(collection.rawValue)")
        var query: Query = db.collection(collection.rawValue).limit(to: limit)
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching paginated documents: \(error.localizedDescription)")
                completion(nil, error)
            } else {
                print("Paginated documents retrieved successfully")
                completion(snapshot?.documents, nil)
            }
        }
    }

    func countDocuments(in collection: Collection, completion: @escaping (Int?, Error?) -> Void) {
        if disabled { completion(0, nil); return }
        print("Counting documents in collection: \(collection.rawValue)")
        db.collection(collection.rawValue).getDocuments { snapshot, error in
            if let error = error {
                print("Error counting documents: \(error.localizedDescription)")
                completion(nil, error)
            } else {
                print("Documents counted successfully")
                completion(snapshot?.documents.count, nil)
            }
        }
    }

    func searchDocuments(in collection: Collection, field: String, value: String, completion: @escaping ([QueryDocumentSnapshot]?, Error?) -> Void) {
        if disabled { completion([], nil); return }
        print("Searching documents in collection: \(collection.rawValue) with field: \(field) and value: \(value)")
        db.collection(collection.rawValue).whereField(field, isEqualTo: value).getDocuments { snapshot, error in
            if let error = error {
                print("Error searching documents: \(error.localizedDescription)")
                completion(nil, error)
            } else {
                print("Documents searched successfully")
                completion(snapshot?.documents, nil)
            }
        }
    }


    func createOrUpdateDocument(in collection: Collection, documentId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        if disabled {
            // Don't create or update document when disabled
            completion(nil)
            return
        }
        print("Creating or updating document in collection: \(collection.rawValue) with id: \(documentId)")
        db.collection(collection.rawValue).document(documentId).setData(data, merge: true) { error in
            if let error = error {
                print("Error creating or updating document: \(error.localizedDescription)")
            } else {
                print("Document created or updated successfully")
            }
            completion(error)
        }
    }

    func performTransaction(in collection: Collection, documentId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        if disabled {
            // Don't perform transaction when disabled
            completion(nil)
            return
        }
        print("Performing transaction in collection: \(collection.rawValue) with id: \(documentId)")
        let documentRef = db.collection(collection.rawValue).document(documentId)

        db.runTransaction { (transaction, errorPointer) -> Any? in
            transaction.updateData(data, forDocument: documentRef)
            return nil
        } completion: { _, error in
            if let error = error {
                print("Error performing transaction: \(error.localizedDescription)")
            } else {
                print("Transaction performed successfully")
            }
            completion(error)
        }
    }
}
