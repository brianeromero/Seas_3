//
//  FacebookHelper.swift
//  Mat_Finder
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
    
    static func handleFacebookLogin(authState: AuthenticationState) {
        if let token = AccessToken.current, !token.isExpired {
            let tokenString = token.tokenString
            let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)
            authenticateWithFacebookCredential(credential, authState: authState)

        } else if AccessToken.current != nil {
            // Token exists but is expired
            AccessToken.refreshCurrentAccessToken { _, _, error in
                DispatchQueue.main.async {
                    if error != nil {
                        return
                    } else if let refreshedToken = AccessToken.current {
                        let tokenString = refreshedToken.tokenString
                        let credential = FacebookAuthProvider.credential(withAccessToken: tokenString)
                        authenticateWithFacebookCredential(credential, authState: authState)
                    }
                }
            }
        } else {
            // No token exists at all — login required
            loginUser(authState: authState)
        }
    }

    private static func loginUser(authState: AuthenticationState) {
        let loginManager = LoginManager()
        
        // Get the root view controller
        if let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first })
            .first(where: { $0.isKeyWindow })?
            .rootViewController {
            
            loginManager.logIn(permissions: ["public_profile", "email"], from: rootVC) { result, error in
                if error != nil {
                    return
                }

                guard let result = result, !result.isCancelled else {
                    return
                }

                // Handle declined permissions
                if result.declinedPermissions.contains("email") {
                    // Optional: Show UI to explain why email is needed
                }

                guard let accessToken = AccessToken.current?.tokenString else {
                    return
                }

                let credential = FacebookAuthProvider.credential(withAccessToken: accessToken)
                authenticateWithFacebookCredential(credential, authState: authState)
            }
        } else {
            // Couldn't get root view controller
        }
    }

    private static func fetchFacebookProfile(authState: AuthenticationState) {
        let request = GraphRequest(graphPath: "me", parameters: ["fields": graphFields])
        request.start { _, result, error in
            if let error = error as NSError? {
                let fbCode = error.userInfo["com.facebook.sdk:FBSDKGraphRequestErrorGraphErrorCode"] as? Int
                if fbCode == 200 {
                    return
                } else {
                    return
                }
            }

            guard let result = result as? [String: Any] else {
                return
            }

            _ = result["id"] as? String ?? "N/A"
            _ = result["name"] as? String ?? "N/A"
            _ = result["email"] as? String ?? "N/A"
            // Optional: Pass this data to update Firebase user profile, or prefill UI
        }
    }

    private static func authenticateWithFacebookCredential(_ credential: AuthCredential, authState: AuthenticationState) {
        Auth.auth().signIn(with: credential) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    authState.handleSignInError(error, message: "Authentication failed")
                } else if let user = result?.user {
                    Task {
                        await authState.handleSuccessfulLogin(provider: .facebook, user: user)
                    }
                } else {
                    authState.handleSignInError(nil, message: "Unknown authentication error.")
                }
            }
        }
    }
}
