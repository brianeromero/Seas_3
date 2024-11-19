//
//  FirestoreManager.swift
//  Seas_3
//

import Foundation
import Firebase
import FirebaseFirestore

class FirestoreManager {
    let db = Firestore.firestore()
    
    // MARK: - Collection-specific functions
    enum Collection: String {
        case appDayOfWeeks
        case matTimes
        case pirateIslands
        case reviews
        case userInfos
    }
    
    // appDayOfWeeks
    func createAppDayOfWeek(data: [String: Any], completion: @escaping (Error?) -> Void) {
        createDocument(collection: Collection.appDayOfWeeks.rawValue, data: data, completion: completion)
    }

    func getAppDayOfWeeks(completion: @escaping ([QueryDocumentSnapshot]?, Error?) -> Void) {
        getDocuments(collection: Collection.appDayOfWeeks.rawValue, completion: completion)
    }
    // MARK: - Generic Firestore Operations
    func createDocument(collection: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection(collection).document().setData(data) { error in
            if let error = error {
                print("Error creating document: \(error.localizedDescription)")
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func getDocuments(collection: String, completion: @escaping ([QueryDocumentSnapshot]?, Error?) -> Void) {
        db.collection(collection).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching documents: \(error.localizedDescription)")
                completion(nil, error)
            } else if let snapshot = snapshot {
                completion(snapshot.documents, nil)
            }
        }
    }

    func updateDocument(collection: String, id: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection(collection).document(id).updateData(data) { error in
            completion(error)
        }
    }

    func deleteDocument(collection: String, id: String, completion: @escaping (Error?) -> Void) {
        db.collection(collection).document(id).delete { error in
            completion(error)
        }
    }

    // MARK: - Error Handling
    enum FirestoreError: Error {
        case documentNotFound
        case invalidData
        case unknownError
        
        var localizedDescription: String {
            switch self {
            case .documentNotFound:
                return "Document not found"
            case .invalidData:
                return "Invalid data"
            case .unknownError:
                return "Unknown error"
            }
        }
    }
    
    // Usage of error handling with completion blocks
    func createAppDayOfWeek(data: [String: Any]) {
        createDocument(collection: Collection.appDayOfWeeks.rawValue, data: data) { error in
            if let error = error {
                print("Failed to create AppDayOfWeek: \(error.localizedDescription)")
            } else {
                print("AppDayOfWeek created successfully")
            }
        }
    }
    
    // MARK: - Additional Functions
    func getAppDayOfWeek(for day: String, completion: @escaping (QueryDocumentSnapshot?) -> Void) {
        getDocuments(collection: Collection.appDayOfWeeks.rawValue) { documents, error in
            if let error = error {
                print("Error fetching documents: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let filteredDocument = documents?.first { $0.get("day") as? String == day }
            completion(filteredDocument)
        }
    }
    
    func getMatTimes(for appDayOfWeekID: String, completion: @escaping ([QueryDocumentSnapshot]) -> Void) {
        getDocuments(collection: Collection.matTimes.rawValue) { documents, error in
            if let error = error {
                print("Error fetching documents: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let filteredDocuments = documents?.filter { $0.get("appDayOfWeekID") as? String == appDayOfWeekID } ?? []
            completion(filteredDocuments)
        }
    }

    // MARK: - Additional Functions for other collections
    func getPirateIsland(for id: String, completion: @escaping (QueryDocumentSnapshot?) -> Void) {
        getDocuments(collection: Collection.pirateIslands.rawValue) { documents, error in
            if let error = error {
                print("Error fetching PirateIsland: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            let filteredDocument = documents?.first { $0.documentID == id }
            completion(filteredDocument)
        }
    }
    
    func getReviews(for pirateIslandID: String, completion: @escaping ([QueryDocumentSnapshot]) -> Void) {
        getDocuments(collection: Collection.reviews.rawValue) { documents, error in
            if let error = error {
                print("Error fetching reviews: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let filteredDocuments = documents?.filter { $0.get("pirateIslandID") as? String == pirateIslandID } ?? []
            completion(filteredDocuments)
        }
    }
    
    
    func listenForChanges(collection: String, completion: @escaping ([QueryDocumentSnapshot]?) -> Void) {
        db.collection(collection).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening for changes: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(snapshot?.documents)
            }
        }
    }
    
    
    func getDocumentById(collection: String, documentId: String, completion: @escaping (DocumentSnapshot?) -> Void) {
        db.collection(collection).document(documentId).getDocument { document, error in
            if let error = error {
                print("Error getting document: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(document)
            }
        }
    }
    
    
    func performBatchOperations(operations: [(operation: FirestoreBatchOperation, collection: String, data: [String: Any])], completion: @escaping (Error?) -> Void) {
        let batch = db.batch()
        for operation in operations {
            let documentRef = db.collection(operation.collection).document()
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
            completion(error)
        }
    }

    enum FirestoreBatchOperation {
        case create
        case update
        case delete
    }

    func getPaginatedDocuments(collection: String, lastDocument: QueryDocumentSnapshot?, limit: Int, completion: @escaping ([QueryDocumentSnapshot]?, Error?) -> Void) {
        var query: Query = db.collection(collection).limit(to: limit)
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching documents: \(error.localizedDescription)")
                completion(nil, error)
            } else if let snapshot = snapshot {
                completion(snapshot.documents, nil)
            }
        }
    }
    func countDocuments(collection: String, completion: @escaping (Int?, Error?) -> Void) {
        db.collection(collection).getDocuments { snapshot, error in
            if let error = error {
                print("Error counting documents: \(error.localizedDescription)")
                completion(nil, error)
            } else {
                completion(snapshot?.documents.count, nil)
            }
        }
    }

    func searchDocuments(collection: String, field: String, value: String, completion: @escaping ([QueryDocumentSnapshot]?, Error?) -> Void) {
        db.collection(collection)
          .whereField(field, isEqualTo: value)
          .getDocuments { snapshot, error in
              if let error = error {
                  print("Error searching documents: \(error.localizedDescription)")
                  completion(nil, error)
              } else {
                  completion(snapshot?.documents, nil)
              }
          }
    }

    func createOrUpdateDocument(collection: String, documentId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection(collection).document(documentId).setData(data, merge: true) { error in
            completion(error)
        }
    }
    
    func performTransaction(collection: String, documentId: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        let documentRef = db.collection(collection).document(documentId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            transaction.updateData(data, forDocument: documentRef)
            return nil
        }) { (object, error) in
            completion(error)
        }
    }


}
