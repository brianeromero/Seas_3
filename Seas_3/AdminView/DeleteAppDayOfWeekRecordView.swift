//
//  DeleteAppDayOfWeekRecordView.swift
//  Seas_3
//
//  Created by Brian Romero on 3/17/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import CoreData


struct DeleteAppDayOfWeekRecordView: View {
    @State private var recordID: String = ""
    @State private var statusMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""

    let coreDataContext: NSManagedObjectContext
    let firestoreManager: FirestoreManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete AppDayOfWeek Record")
                .font(.title)
                .bold()
            
            TextField("Enter Record ID", text: $recordID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                deleteRecordAndHandleCache(recordID: recordID)
            }) {
                Text("Delete AppDayOfWeek Record")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
            
            if isLoading {
                ProgressView()
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Text(statusMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
    
    func deleteRecordFromFirestore(appDayOfWeekID: String) {
        isLoading = true
        let db = Firestore.firestore()
        
        var query: Query!
        
        if appDayOfWeekID.isEmpty {
            query = db.collection("appDayOfWeeks").whereField("appDayOfWeekID", isEqualTo: NSNull())
        } else {
            query = db.collection("appDayOfWeeks").whereField("appDayOfWeekID", isEqualTo: appDayOfWeekID)
        }
        
        query.getDocuments { querySnapshot, error in
            self.isLoading = false
            if let error = error {
                print("Error deleting record from Firestore: \(error)")
                self.errorMessage = "Error deleting record from Firestore: \(error)"
                return
            }
            
            if let querySnapshot = querySnapshot {
                for document in querySnapshot.documents {
                    document.reference.delete { error in
                        if let error = error {
                            print("Error deleting document from Firestore: \(error)")
                            self.errorMessage = "Error deleting document from Firestore: \(error)"
                        }
                    }
                }
            }
        }
    }

    func deleteRecordFromCoreData(appDayOfWeekID: String) {
        isLoading = true
        let context = coreDataContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "AppDayOfWeek")
        var predicate: NSPredicate!
        
        if appDayOfWeekID.isEmpty {
            predicate = NSPredicate(format: "appDayOfWeekID == nil")
        } else {
            predicate = NSPredicate(format: "appDayOfWeekID == %@", appDayOfWeekID)
        }
        
        fetchRequest.predicate = predicate
        
        do {
            self.isLoading = false
            let objects = try context.fetch(fetchRequest) as? [NSManagedObject]
            if let objects = objects {
                for object in objects {
                    context.delete(object)
                }
                try context.save()
                self.statusMessage = "Record deleted successfully"
            }
        } catch let error {
            print("Error deleting record from Core Data: \(error)")
            self.errorMessage = "Error deleting record from Core Data: \(error)"
        }
    }
    
    func deleteRecordAndHandleCache(recordID: String) {
        if validateRecordID(recordID) {
            deleteRecordFromFirestore(appDayOfWeekID: recordID)
            deleteRecordFromCoreData(appDayOfWeekID: recordID)
        } else {
            statusMessage = "Invalid record ID"
        }
    }
    
    private func validateRecordID(_ recordID: String) -> Bool {
        // Allow for null or empty record IDs
        if recordID.isEmpty {
            return true
        }
        
        // Ensure the recordID is a valid UUID
        guard UUID(uuidString: recordID) != nil else {
            return false
        }
        
        return true
    }
}
