//
//  fetchGoogleUserProfile.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import GoogleSignIn
import CoreData



func fetchGoogleUserProfile(managedObjectContext: NSManagedObjectContext) {
    // Check if current user is signed in
    if let currentUser = GIDSignIn.sharedInstance.currentUser,
       let userProfile = currentUser.profile {
        
        // Log user data for debugging (consider removing in production)
        print("Google Sign-In Current User: \(currentUser)")
        print("Google Sign-In User Profile: \(userProfile)")
        
        // Extract user info
        let userId = currentUser.userID // This is already a String
        let userName = userProfile.name
        let userEmail = userProfile.email
        
        print("User Info: \(userId ?? "nil"), \(userName), \(userEmail)")
        
        // Create or update UserInfo entity
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", userEmail)
        
        DispatchQueue.main.async {
            do {
                // Fetch existing user data
                let users = try managedObjectContext.fetch(fetchRequest)
                var userInfo: UserInfo
                
                // Update existing user or create new one
                if let existingUser = users.first {
                    userInfo = existingUser
                } else {
                    userInfo = UserInfo(context: managedObjectContext)
                }
                
                // Update user info
                userInfo.email = userEmail
                userInfo.name = userName
                userInfo.userName = userName
                userInfo.userID = userId ?? "" // Handle optional correctly if needed
                
                // Save changes to managed object context
                try managedObjectContext.save()
            } catch let error as NSError {
                print("Error fetching or saving user: \(error.localizedDescription), \(error.userInfo)")
            }
        }
        
        // Update AuthenticationState with Google user data
        let authenticationState = AuthenticationState()
        do {
            try authenticationState.updateSocialUser(
                .google,
                userId ?? "",
                userName,
                userEmail
            )
        } catch {
            // Handle update error
            print("Error updating AuthenticationState: \(error.localizedDescription)")
        }
    } else {
        // Handle no current user
        print("No current Google user")
    }
}

