//
//  TokenFetcher.swift
//  Seas_3
//
//  Created by Brian Romero on 10/25/24.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseCore

class TokenFetcher {
    init() {
        FirebaseApp.configure()
        fetchIDToken()
    }
    
    func fetchIDToken() {
        // Get the current user
        if let user = Auth.auth().currentUser {
            user.getIDToken(completion: { idToken, error in
                if let error = error {
                    print("Error getting ID token: \(error.localizedDescription)")
                } else if let idToken = idToken {
                    print("ID Token: \(idToken)")
                    // Use this ID token in your curl request
                }
            })
        } else {
            print("No current user")
        }
    }
}

// Create an instance to run the code
let tokenFetcher = TokenFetcher()
