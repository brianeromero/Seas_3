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
    @State private var statusMessage: String = ""

    let coreDataContext: NSManagedObjectContext
    let firestoreManager: FirestoreManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Gym Record")
                .font(.title)
                .bold()
            
            TextField("Enter Record ID", text: $recordID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                deleteRecordAndHandleCache()
            }) {
                Text("Delete Gym Record")
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
    
    private func deleteRecord(recordID: String, coreDataContext: NSManagedObjectContext) async -> (Bool, String) {
        let db = Firestore.firestore()

        do {
            // Firestore deletion
            try await db.collection("pirateIslands").document(recordID).delete()
            print("Record deleted from Firestore.")
            
            // Core Data deletion
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "PirateIsland")
            fetchRequest.predicate = NSPredicate(format: "islandID == %@", recordID as NSString)
            
            let results = try await coreDataContext.perform {
                try coreDataContext.fetch(fetchRequest) as? [NSManagedObject]
            }
            
            if let results = results, !results.isEmpty {
                for object in results {
                    coreDataContext.delete(object)
                }
                try await coreDataContext.perform {
                    try coreDataContext.save()
                }
                print("Record deleted from Core Data.")
                return (true, "")
            } else {
                return (false, "No matching record found in Core Data.")
            }
        } catch {
            return (false, "Failed to delete from Firestore or Core Data: \(error.localizedDescription)")
        }
    }

    private func deleteRecordAndHandleCache() {
        guard validateRecordID(recordID) else {
            statusMessage = "Invalid Record ID. Please enter a valid UUID."
            return
        }

        Task {
            let (success, message) = await deleteRecord(recordID: recordID, coreDataContext: coreDataContext)
            if success {
                statusMessage = "Record successfully deleted."
            } else {
                statusMessage = "Error: \(message)"
            }
        }
    }
    
    private func validateRecordID(_ recordID: String) -> Bool {
        // Ensure the recordID is a valid UUID
        return UUID(uuidString: recordID) != nil
    }
}
