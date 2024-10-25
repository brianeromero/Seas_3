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

class FacebookHelper {
    
    static func checkFacebookToken() {
        if AccessToken.current?.isExpired ?? true {
            // Let the button handle login
            print("Access token is expired or missing. Not fetching profile.")
            return
        } else {
            // Token is valid, proceed to fetch profile
            FacebookHelper.fetchFacebookUserProfile { userInfo in
                if userInfo != nil {
                    print("Facebook user profile fetched successfully: \(String(describing: userInfo))")
                } else {
                    print("Failed to fetch Facebook user profile.")
                }
            }
        }
    }

    static func handleFacebookLogin() {
        let loginManager = LoginManager()
        loginManager.logIn(permissions: ["public_profile", "email"], from: nil) { result, error in
            
            if let error = error {
                print("Facebook Login Error: \(error.localizedDescription)")
                Analytics.logEvent("facebook_login_error", parameters: ["error": error.localizedDescription])
            } else if let result = result, !result.isCancelled {
                print("Facebook Login Success")
                Analytics.logEvent("facebook_login_success", parameters: nil)
                
                fetchFacebookUserProfile { userInfo in
                    guard let userInfo = userInfo else { return }
                    print("Fetched Facebook user profile: \(userInfo)")
                    
                    // Fetch ios_skadnetwork_conversion_config
                    let params = ["fields": "id,ios_skadnetwork_conversion_config"]
                    let graphRequest = GraphRequest(graphPath: "1057815062545175", parameters: params)
                    graphRequest.start { _, result, error in
                        if let error = error {
                            handleFacebookSDKError(error)
                            return
                        }
                        print("Fetched ios_skadnetwork_conversion_config: \(String(describing: result))")
                    }
                }
            }
        }
    }

    static func fetchFacebookUserProfile(completion: @escaping ([String: Any]?) -> Void) {
        if AccessToken.current?.isExpired ?? false {
            AccessToken.refreshCurrentAccessToken { _, _, error in
                if let error = error {
                    handleFacebookSDKError(error)
                    completion(nil)
                    return
                }
                fetchFacebookUserProfile(completion: completion)
            }
        } else {
            let params = ["fields": "id,name,email,picture"]
            let graphRequest = GraphRequest(graphPath: "me", parameters: params)
            graphRequest.start { _, result, error in
                if let error = error {
                    handleFacebookSDKError(error)
                    completion(nil)
                    return
                }
                completion(result as? [String: Any])
            }
        }
    }
    
    static func handleFacebookSDKError(_ error: Error) {
        print("Facebook SDK Error: \(error.localizedDescription)")
        let errorCode = (error as NSError).code
        switch errorCode {
        case 190:
            print("Invalid OAuth access token signature. Please try again.")
        default:
            print("Unknown Facebook SDK error: \(error.localizedDescription)")
        }
        Analytics.logEvent("facebook_sdk_error", parameters: ["error": error.localizedDescription])
    }
}
