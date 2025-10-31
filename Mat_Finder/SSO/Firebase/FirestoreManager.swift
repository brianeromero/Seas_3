//
//  FirestoreManager.swift
//  Mat_Finder
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import os

public class FirestoreManager {
    public static let shared = FirestoreManager()

    var disabled: Bool = false
    private lazy var db = Firestore.firestore()

    // MARK: - Listener Registrations
    // Declare properties to hold your listener registrations.
    // If you have multiple real-time listeners for different data,
    // you'll need a separate ListenerRegistration for each.
    private var userDocumentListener: ListenerRegistration?
    private var appDayOfWeeksListener: ListenerRegistration? // Example: If you listen to this collection
    private var pirateIslandsListener: ListenerRegistration? // Example: If you listen to this collection

    private init() {
        // You can do any setup here if needed.
        print("FirestoreManager initialized with Firestore instance.")
    }

    
    // MARK: - Real-Time Updates (Modified)
    // You already have a generic `listenForChanges` but it doesn't store the registration.
    // Let's create a more specific one that stores and manages the listener.

    /// Sets up a real-time listener for the user's Firestore document.
    /// Call this when the user logs in and you want to sync their profile data.
    func startListeningForUserDocument() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("FirestoreManager: Cannot start listening for user document, no current Firebase user.")
            return
        }

        // First, remove any existing listener to prevent duplicates.
        // This is crucial to prevent "QUARANTINED DUE TO HIGH LOGGING VOLUME" and stalling.
        userDocumentListener?.remove()
        userDocumentListener = nil // Clear the reference

        print("FirestoreManager: Starting real-time listener for user document: \(userID)")

        userDocumentListener = db.collection("users").document(userID)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard self != nil else { return }

                if let error = error {
                    print("Error listening for user document changes: \(error.localizedDescription)")
                    // Handle error, maybe retry or inform the user
                    return
                }

                guard let document = documentSnapshot else {
                    print("FirestoreManager: User document snapshot is nil.")
                    return
                }

                if document.exists {
                    // Handle user data updates
                    print("FirestoreManager: User document updated for UID: \(userID)")
                    // This is where you would typically update your AuthenticationState.currentUser
                    // or other relevant data models that depend on real-time user profile updates.
                    // Example:
                    // if let updatedUser = User(fromFirestoreDocument: document) {
                    //     AuthenticationState.shared.currentUser = updatedUser
                    // }
                } else {
                    print("FirestoreManager: User document does not exist for UID: \(userID)")
                    // This could mean the user's profile was deleted from Firestore.
                    // You might want to trigger a logout or adjust app state accordingly.
                }
            }
    }

    
    // MARK: - Cleanup Method
    /// Stops all active Firestore real-time listeners.
    /// This should be called when the user logs out to prevent memory leaks and unnecessary data fetching.
    public func stopAllListeners() {
        print("FirestoreManager: Stopping all active Firestore listeners.")
        userDocumentListener?.remove()
        userDocumentListener = nil

        appDayOfWeeksListener?.remove()
        appDayOfWeeksListener = nil

        pirateIslandsListener?.remove()
        pirateIslandsListener = nil
        // Add .remove() and nil out all other ListenerRegistration properties you have
        // Example: someOtherCollectionListener?.remove(); someOtherCollectionListener = nil
    }

    
    /// Sets up a real-time listener for general collection changes.
    /// This is an example of how you could adapt your existing `listenForChanges`
    /// to store and manage its listener registration.
    func startListeningForCollection(collection: Collection, completion: @escaping ([QueryDocumentSnapshot]?) -> Void) {
        if disabled { return }

        // Decide if you need separate listener properties for each collection,
        // or a dictionary if you'll listen to many dynamically.
        // For simplicity, let's assume we manage specific ones for now.
        // If this is for `appDayOfWeeks`, you'd do:
        // appDayOfWeeksListener?.remove()
        // appDayOfWeeksListener = nil

        print("FirestoreManager: Starting listening for changes in collection: \(collection.rawValue)")

        // For `appDayOfWeeks` listener:
        if collection == .appDayOfWeeks {
            appDayOfWeeksListener?.remove() // Remove previous listener if it exists
            appDayOfWeeksListener = db.collection(collection.rawValue).addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for changes in \(collection.rawValue): \(error.localizedDescription)")
                    completion(nil)
                } else {
                    print("Changes detected in collection: \(collection.rawValue)")
                    completion(snapshot?.documents)
                }
            }
        }
        // Add more `if` blocks for other specific collections you want to listen to.
        // Or, for a more general approach, you could use a `[Collection: ListenerRegistration]` dictionary.
    }


    
    
    
    // MARK: - Save PirateIsland to Firestore
    func saveIslandToFirestore(
        islandData: FirestoreIslandData,
        selectedCountry: Country,
        createdByUser: User
    ) async throws {
        if disabled { return }

        let islandRef = db.collection("pirateIslands").document(islandData.id)

        let data: [String: Any] = [
            "id": islandData.id,
            "name": islandData.name,
            "location": islandData.location,
            "country": islandData.country,
            "createdByUserId": islandData.createdByUserId,
            "createdTimestamp": islandData.createdTimestamp,
            "lastModifiedByUserId": islandData.lastModifiedByUserId,
            "lastModifiedTimestamp": islandData.lastModifiedTimestamp,
            "latitude": islandData.latitude,
            "longitude": islandData.longitude,
            "gymWebsite": islandData.gymWebsite,
            "createdBy": [
                "id": createdByUser.id,
                "name": createdByUser.userName,
                "email": createdByUser.email
            ]
        ]

        try await islandRef.setData(data, merge: true)
        os_log("✅ Saved PirateIsland %@ to Firestore", log: .default, type: .info, islandData.name)
    }


    // MARK: - Collection Management
    enum Collection: String {
        case appDayOfWeeks, matTimes, pirateIslands, reviews, userInfos, users // Added 'users' collection
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

    
    // MARK: - Specific Functions for Collections (existing, just adding 'users' to the enum and comments)
    // Note: If you're listening for user profiles, your User object should handle decoding a document.
    // The `getPirateIsland(for id:)` and `getReviews(for pirateIslandID:)` methods are for one-time fetches,
    // not real-time listeners.
    
    
    
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
    
    // MARK: - Delete Review from Firestore
    func deleteReview(_ review: Review, completion: @escaping (Result<Void, Error>) -> Void) {
        if disabled {
            completion(.success(())) // Do nothing if FirestoreManager is disabled
            return
        }

        // ✅ Use reviewID (UUID) instead of NSManagedObjectID
        let reviewIDString = review.reviewID.uuidString

        print("FirestoreManager: Deleting review with id: \(reviewIDString)")

        db.collection(Collection.reviews.rawValue).document(reviewIDString).delete { error in
            if let error = error {
                print("FirestoreManager: Failed to delete review: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("FirestoreManager: Review deleted successfully from Firestore")
                completion(.success(()))
            }
        }
    }


}
