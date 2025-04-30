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
    
    private static let graphFields = "id,name,email"
    
    static func handleFacebookLogin(authManager: AuthenticationManager) {
        if let token = AccessToken.current, !token.isExpired {
            authManager.log(message: "Facebook access token is valid. Proceeding to authenticate...", level: .info)
            let tokenString = token.tokenString
            let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)
            authenticateWithFacebookCredential(credential, authManager: authManager)

        } else if AccessToken.current != nil {
            // Token exists but is expired
            authManager.log(message: "Facebook token expired. Attempting to refresh...", level: .info)
            AccessToken.refreshCurrentAccessToken { _, _, error in
                DispatchQueue.main.async {
                    if let error = error {
                        authManager.log(message: "Error refreshing Facebook token: \(error.localizedDescription)", level: .error)
                    } else if let refreshedToken = AccessToken.current {
                        authManager.log(message: "Facebook token refreshed.", level: .info)
                        let tokenString = refreshedToken.tokenString
                        let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)
                        authenticateWithFacebookCredential(credential, authManager: authManager)
                    }
                }
            }
        } else {
            // No token exists at all — login required
            loginUser(authManager: authManager)
        }
    }

    private static func loginUser(authManager: AuthenticationManager) {
        let loginManager = LoginManager()
        
        // Get the root view controller
        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {
            
            loginManager.logIn(permissions: ["public_profile", "email"], from: rootVC) { result, error in
                if let error = error {
                    authManager.log(message: "Facebook Login Error: \(error.localizedDescription)", level: .error)
                    return
                }

                guard let result = result, !result.isCancelled else {
                    authManager.log(message: "Facebook login was cancelled.", level: .warning)
                    return
                }

                // Handle declined permissions
                if result.declinedPermissions.contains("email") {
                    authManager.log(message: "⚠️ User declined email permission.", level: .warning)
                    // Optional: Show UI to explain why email is needed
                    // Or allow limited access, or prompt later
                }

                guard let accessToken = AccessToken.current?.tokenString else {
                    authManager.log(message: "⚠️ Failed to get Facebook access token after login.", level: .error)
                    return
                }

                authManager.log(message: "Facebook Login Success", level: .info)
                let credential = FacebookAuthProvider.credential(withAccessToken: accessToken)
                authenticateWithFacebookCredential(credential, authManager: authManager)
            }
        } else {
            authManager.log(message: "⚠️ Could not find the root view controller.", level: .error)
        }
    }


    private static func fetchFacebookProfile(authManager: AuthenticationManager) {
        let request = GraphRequest(graphPath: "me", parameters: ["fields": graphFields])
        request.start { _, result, error in
            if let error = error as NSError? {
                let fbCode = error.userInfo["com.facebook.sdk:FBSDKGraphRequestErrorGraphErrorCode"] as? Int
                if fbCode == 200 {
                    authManager.log(message: "❌ Missing Facebook permission (code 200). Possibly revoked permission like email.", level: .error)
                    return
                } else {
                    authManager.log(message: "❌ Facebook Graph API error: \(error.localizedDescription)", level: .error)
                    return
                }
            }

            guard let result = result as? [String: Any] else {
                authManager.log(message: "⚠️ Unknown error or malformed response fetching Facebook profile.", level: .warning)
                return
            }

            let id = result["id"] as? String ?? "N/A"
            let name = result["name"] as? String ?? "N/A"
            let email = result["email"] as? String ?? "N/A"
            authManager.log(message: "✅ Facebook user: \(name) | Email: \(email) | ID: \(id)", level: .info)
            
            // Optional: Pass this data to update Firebase user profile, or prefill UI
        }
    }

    private static func authenticateWithFacebookCredential(_ credential: AuthCredential, authManager: AuthenticationManager) {
        authManager.handleAuthentication(with: credential) { result in
            switch result {
            case .success(_):
                authManager.log(message: "Successfully authenticated with Firebase.", level: .info)
                fetchFacebookProfile(authManager: authManager)
            case .failure(let error):
                authManager.log(message: "Authentication failed: \(error.localizedDescription)", level: .error)
            }
        }
    }
}
