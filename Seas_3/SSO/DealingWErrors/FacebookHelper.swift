//
//  FacebookHelper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import FBSDKLoginKit
import FBSDKCoreKit
import FirebaseAnalytics
import FirebaseAuth
import FirebaseCore
import os

enum FacebookError: Error {
    case expiredAccessToken
    case invalidOAuthToken
    case unknownError(Error)
    
    var localizedDescription: String {
        switch self {
        case .expiredAccessToken:
            return "Access token is expired."
        case .invalidOAuthToken:
            return "Invalid OAuth access token signature."
        case .unknownError(let error):
            return error.localizedDescription
        }
    }
}

class FacebookHelper {
    static func handleFacebookLogin(authManager: AuthenticationManager) {
        _ = LoginManager()

        // Check if the access token is expired and refresh if necessary
        if AccessToken.current?.isExpired ?? false {
            AccessToken.refreshCurrentAccessToken { _, _, error in
                if let error = error {
                    authManager.log(message: "Error refreshing Facebook token: \(error.localizedDescription)", level: .error)
                    return
                } else {
                    authManager.log(message: "Facebook token refreshed.", level: .info)
                    // Now proceed to authenticate after refreshing the token
                    loginUser(authManager: authManager)
                }
            }
        } else {
            loginUser(authManager: authManager) // Proceed to login if the token is still valid
        }
    }

    private static func loginUser(authManager: AuthenticationManager) {
        let loginManager = LoginManager()
        loginManager.logIn(permissions: ["public_profile", "email"], from: nil) { result, error in
            if let error = error {
                authManager.log(message: "Facebook Login Error: \(error.localizedDescription)", level: .error)
                return
            }

            guard let result = result, !result.isCancelled, let accessToken = AccessToken.current?.tokenString else {
                authManager.log(message: "Facebook login was cancelled.", level: .warning)
                return
            }

            authManager.log(message: "Facebook Login Success", level: .info)
            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken)
            authenticateWithFacebookCredential(credential, authManager: authManager)
        }
    }

    private static func authenticateWithFacebookCredential(_ credential: AuthCredential, authManager: AuthenticationManager) {
        // Delegate authentication to AuthenticationManager
        authManager.handleAuthentication(with: credential) { result in
            switch result {
            case .success(_):
                authManager.log(message: "Successfully authenticated with Firebase.", level: .info)
                // Handle the user object here if needed
            case .failure(let error):
                authManager.log(message: "Authentication failed: \(error.localizedDescription)", level: .error)
            }
        }
    }
}
