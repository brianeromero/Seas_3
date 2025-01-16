//
//  DeleteUserView.swift
//  Seas_3
//
//  Created by Brian Romero on 1/6/25.
//

import Foundation
import SwiftUI
import CoreData

struct DeleteUserView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @State private var userID: String = ""
    @State private var statusMessage: String = ""

    let coreDataContext: NSManagedObjectContext

    var body: some View {
        VStack(spacing: 20) {
            Text("Delete User")
                .font(.title)
                .bold()
            
            TextField("Enter User ID", text: $userID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                deleteUserAndHandleCache()
            }) {
                Text("Delete User")
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
    
    private func deleteUser(userID: String, coreDataContext: NSManagedObjectContext) async -> (Bool, String) {
        do {
            // Delete user from Core Data
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "UserInfo")
            fetchRequest.predicate = NSPredicate(format: "userID == %@", userID as NSString)
            
            let results = try await coreDataContext.perform {
                try coreDataContext.fetch(fetchRequest) as? [NSManagedObject]
            }
            
            if let results = results {
                for object in results {
                    coreDataContext.delete(object)
                }
                try await coreDataContext.perform {
                    try coreDataContext.save()
                }
                print("User deleted from Core Data.")
                return (true, "")
            } else {
                return (false, "Failed to delete from Core Data: No results found")
            }
        } catch {
            print("Error deleting user: \(error.localizedDescription)")
            return (false, "Failed to delete from Core Data: \(error.localizedDescription)")
        }
    }

    private func deleteUserAndHandleCache() {
        guard !userID.isEmpty else {
            statusMessage = "Please enter a valid User ID."
            return
        }

        Task {
            let (success, message) = await deleteUser(userID: userID, coreDataContext: coreDataContext)
            if success {
                statusMessage = "User successfully deleted."
            } else {
                statusMessage = "Error: \(message)"
            }
        }
    }
}
