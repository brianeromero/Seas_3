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
    if let currentUser = GIDSignIn.sharedInstance.currentUser,
       let userProfile = currentUser.profile {
        let userId = currentUser.userID
        let userName = userProfile.name
        let userEmail = userProfile.email
        
        print("User Info: \(String(describing: userId)), \(userName), \(userEmail)")
        
        // Create or update UserInfo entity
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", userEmail)
        
        do {
            let users = try managedObjectContext.fetch(fetchRequest)
            var userInfo: UserInfo
            
            if let existingUser = users.first {
                userInfo = existingUser
            } else {
                userInfo = UserInfo(context: managedObjectContext)
            }
            
            userInfo.email = userEmail
            userInfo.name = userName
            userInfo.userName = userName
            userInfo.userID = UUID(uuidString: userId ?? "")
            
            try managedObjectContext.save()
        } catch {
            print("Error fetching or saving user: \(error.localizedDescription)")
        }
        
        // Update AuthenticationState with Google user data
        let authenticationState = AuthenticationState()
        authenticationState.updateGoogleUser(userId, userName, userEmail)
    } else {
        print("No current Google user")
    }
}
