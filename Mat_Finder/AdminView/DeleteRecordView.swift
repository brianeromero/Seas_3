//
//  DeleteRecordView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 12/17/24.
//


import Foundation
import SwiftUI
import FirebaseFirestore
@preconcurrency import CoreData

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
            return await withCheckedContinuation { continuation in
                coreDataContext.perform {
                    do {
                        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "islandID == %@", recordID)
                        
                        let results = try coreDataContext.fetch(fetchRequest)
                        
                        if results.isEmpty {
                            continuation.resume(returning: (false, "No matching record found in Core Data."))
                            return
                        }
                        
                        for object in results {
                            coreDataContext.delete(object)
                        }
                        
                        try coreDataContext.save()
                        print("Record deleted from Core Data.")
                        continuation.resume(returning: (true, ""))
                        
                    } catch {
                        continuation.resume(returning: (false, "Core Data error: \(error.localizedDescription)"))
                    }
                }
            }
            
        } catch {
            return (false, "Firestore deletion failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func deleteRecordAndHandleCache() {
        guard validateRecordID(recordID) else {
            statusMessage = "Invalid Record ID. Please enter a valid UUID."
            return
        }

        Task {
            let (success, message) = await deleteRecord(recordID: recordID, coreDataContext: coreDataContext)
            // Always update UI on main thread
            await MainActor.run {
                statusMessage = success ? "Record successfully deleted." : "Error: \(message)"
            }
        }
    }
    
    private func validateRecordID(_ recordID: String) -> Bool {
        // Ensure the recordID is a valid UUID
        return UUID(uuidString: recordID) != nil
    }
}
