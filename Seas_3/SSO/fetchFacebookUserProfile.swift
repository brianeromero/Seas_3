//
//  fetchFacebookUserProfile.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//

import Foundation
import SwiftUI
import FBSDKCoreKit

// Define a standalone function to handle Facebook SDK errors
func handleFacebookSDKError(_ error: Error) {
    let errorCode = (error as NSError).code
    switch errorCode {
    case 190:
        print("Invalid OAuth access token signature. Please try again.")
    default:
        print("Unknown Facebook SDK error: \(error.localizedDescription)")
    }
}

func fetchFacebookUserProfile() {
    if AccessToken.current?.isExpired ?? false {
        // Refresh token or handle expiration
    } else {
        let graphRequest = GraphRequest(
            graphPath: "me",
            parameters: ["fields": "id, name, email"]
        )
        graphRequest.start { _, result, error in
            if let error = error {
                handleFacebookSDKError(error) // Call standalone error handling function
                print("Graph API error: \(error.localizedDescription)")
            } else if let result = result as? [String: Any] {
                print("User Info: \(result)")
            }
        }
    }
}
