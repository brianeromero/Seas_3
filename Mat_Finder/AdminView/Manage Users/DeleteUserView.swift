//
//  DeleteUserView.swift
//  Mat_Finder
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
                .foregroundColor(.primary) // Ensure title text is adaptive

            TextField("Enter User ID", text: $userID)
                .textFieldStyle(RoundedBorderTextFieldStyle()) // This style is adaptive
                .padding(.horizontal) // Apply horizontal padding directly to TextField

            Button(action: {
                deleteUserAndHandleCache()
            }) {
                Text("Delete User")
                    .font(.headline)
                    .foregroundColor(.white) // White on Red is good contrast in both modes
                    .padding()
                    .frame(maxWidth: .infinity) // Make button fill width
                    .background(Color.red) // Red is a strong color, typically okay in both modes
                    .cornerRadius(10)
            }
            .padding(.horizontal) // Apply horizontal padding to the button

            Text(statusMessage)
                .foregroundColor(.secondary) // Use .secondary for adaptive subdued text
                .multilineTextAlignment(.center)
                .padding(.horizontal) // Apply horizontal padding
        }
        .padding(.vertical) // Vertical padding for the VStack content
        .background(Color(uiColor: .systemBackground)) // Use system background for the view's overall background
        .ignoresSafeArea() // Extend background to safe areas if desired
    }
    
    private func deleteUser(userID: String, coreDataContext: NSManagedObjectContext) async -> (Bool, String) {
        do {
            // Delete user from Core Data
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "UserInfo")
            fetchRequest.predicate = NSPredicate(format: "userID == %@", userID as NSString)
            
            let results = try await coreDataContext.perform {
                try coreDataContext.fetch(fetchRequest) as? [NSManagedObject]
            }
            
            if let results = results, !results.isEmpty { // Added check for empty results
                for object in results {
                    coreDataContext.delete(object)
                }
                try await coreDataContext.perform {
                    try coreDataContext.save()
                }
                print("User deleted from Core Data.")
                return (true, "")
            } else {
                return (false, "Failed to delete from Core Data: No user found with this ID.")
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
