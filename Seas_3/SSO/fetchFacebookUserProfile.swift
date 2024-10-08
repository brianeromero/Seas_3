//
//  fetchFacebookUserProfile.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//

import Foundation
import SwiftUI
import FBSDKCoreKit

func fetchFacebookUserProfile() {
    let request = GraphRequest(graphPath: "me", parameters: ["fields": "id, name, email"])
    request.start { _, result, error in
        if let error = error {
            print("Failed to fetch user profile: \(error)")
        } else if let result = result as? [String: Any] {
            print("User Info: \(result)")
        }
    }
}

