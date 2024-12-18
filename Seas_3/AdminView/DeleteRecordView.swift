//
//  DeleteRecordView.swift
//  Seas_3
//
//  Created by Brian Romero on 12/17/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import CoreData

struct DeleteRecordView: View {
    @State private var recordID: String = ""
    @State private var clearCache: Bool = false
    @State private var statusMessage: String = ""

    let coreDataContext: NSManagedObjectContext
    let firestoreManager: FirestoreManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Record")
                .font(.title)
                .bold()
            
            TextField("Enter Record ID", text: $recordID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Toggle("Clear Firestore Cache", isOn: $clearCache)
                .padding(.horizontal)

            Button(action: {
                deleteRecordAndHandleCache()
            }) {
                Text("Delete Record")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            
            Text(statusMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }

    private func deleteRecordAndHandleCache() {
        guard !recordID.isEmpty else {
            statusMessage = "Please enter a valid Record ID."
            return
        }

        Task {
            do {
                try await firestoreManager.deleteDocument(in: .pirateIslands, id: recordID)
                statusMessage = "Record successfully deleted."
                if clearCache {
                    clearFirestoreCache()
                }
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func deleteRecord(recordID: String, coreDataContext: NSManagedObjectContext, completion: @escaping (Bool, String) -> Void) {
        let db = Firestore.firestore()

        db.collection("pirateIslands").document(recordID).delete { error in
            if let error = error {
                completion(false, "Failed to delete from Firestore: \(error.localizedDescription)")
            } else {
                print("Record deleted from Firestore.")
                
                let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "PirateIsland")
                fetchRequest.predicate = NSPredicate(format: "id == %@", recordID)
                
                do {
                    let results = try coreDataContext.fetch(fetchRequest)
                    for object in results {
                        if let managedObject = object as? NSManagedObject {
                            coreDataContext.delete(managedObject)
                        }
                    }
                    try coreDataContext.save()
                    print("Record deleted from Core Data.")
                    completion(true, "")
                } catch {
                    completion(false, "Failed to delete from Core Data: \(error.localizedDescription)")
                }
            }
        }
    }

    private func clearFirestoreCache() {
        Firestore.firestore().clearPersistence()
        print("Firestore cache cleared successfully.")
    }
}
