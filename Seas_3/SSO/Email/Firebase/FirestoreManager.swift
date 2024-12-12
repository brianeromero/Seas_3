//
//  FirestoreManager.swift
//  Seas_3
//

import Foundation
import Firebase
import FirebaseFirestore

class FirestoreManager {
    static let shared = FirestoreManager()
    
    private let db: Firestore
    
    private init() {
        self.db = Firestore.firestore()
    }

    // MARK: - User Management
    func createUser(userName: String, name: String) async throws {
        print("Creating user with username: \(userName) and name: \(name)")
        try await setDocument(in: .userInfos, id: userName, data: [
            "userName": userName,
            "name": name
        ])
        print("User created successfully")
    }
    
    func createFirestoreUser(userName: String, name: String) async throws {
        print("Creating Firestore user with username: \(userName) and name: \(name)")
        // Implementation to add user details to Firestore
        let userRef = db.collection("users").document("user-\(userName)")
        try await userRef.setData([
            "name": name,
            "userName": userName,
            "createdAt": FieldValue.serverTimestamp()
        ])
        print("Firestore user created successfully")
    }
    

    func saveIslandToFirestore(island: PirateIsland) async throws {
        print("Saving island to Firestore: \(island.safeIslandName)")
        
        // Add some debug prints here
        print("Island name: \(island.islandName ?? "")")
        print("Island location: \(island.islandLocation ?? "")")
        print("Gym website URL: \(island.gymWebsite?.absoluteString ?? "")")
        print("Latitude: \(island.latitude)")
        print("Longitude: \(island.longitude)")
        
        // Validate data
        guard let islandName = island.islandName, !islandName.isEmpty,
              let islandLocation = island.islandLocation, !islandLocation.isEmpty else {
            print("Invalid data: Island name or location is missing")
            return
        }
        
        // Use the correct property names from PirateIsland
        let islandRef = db.collection("pirateIslands").document(island.islandID?.uuidString ?? UUID().uuidString)
        try await islandRef.setData([
            "id": island.islandID?.uuidString ?? UUID().uuidString,
            "name": island.safeIslandName,
            "location": island.safeIslandLocation,
            "country": island.country ?? "",
            "createdByUserId": island.createdByUserId ?? "Unknown User",
            "createdTimestamp": island.createdTimestamp ?? Date(),
            "lastModifiedByUserId": island.lastModifiedByUserId ?? "",
            "lastModifiedTimestamp": island.lastModifiedTimestamp ?? Date(),
            "latitude": island.latitude,
            "longitude": island.longitude,
            "gymWebsite": island.gymWebsite?.absoluteString ?? ""
        ])
        print("Island saved successfully to Firestore")
    }

    // MARK: - Collection Management
    enum Collection: String {
        case appDayOfWeeks, matTimes, pirateIslands, reviews, userInfos
    }

    func updatePirateIsland(id: String, data: [String: Any]) async throws {
        print("Updating pirate island with id: \(id)")
        try await updateDocument(in: .pirateIslands, id: id, data: data)
        print("Pirate island updated successfully")
    }

    func createAppDayOfWeek(data: [String: Any]) async throws {
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
        print("Creating document in collection: \(collection.rawValue)")
        try await db.collection(collection.rawValue).document().setData(data)
        print("Document created successfully")
    }

    internal func updateDocument(in collection: Collection, id: String, data: [String: Any]) async throws {
        print("Updating document in collection: \(collection.rawValue) with id: \(id)")
        try await db.collection(collection.rawValue).document(id).setData(data, merge: false)
        print("Document updated successfully")
    }
    
    internal func deleteDocument(in collection: Collection, id: String) async throws {
        print("Deleting document in collection: \(collection.rawValue) with id: \(id)")
        try await db.collection(collection.rawValue).document(id).delete()
        print("Document deleted successfully")
    }

    internal func getDocuments(in collection: Collection) async throws -> [QueryDocumentSnapshot] {
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
        print("Searching documents in collection: \(collection.rawValue) with field: \(field) and value: \(value)")
        db.collection(collection.rawValue)
          .whereField(field, isEqualTo: value)
          .getDocuments { snapshot, error in
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
