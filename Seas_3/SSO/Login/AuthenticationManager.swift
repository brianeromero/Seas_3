//
//  AuthenticationManager.swift
//  Seas_3
//
//  Created by Brian Romero on 2/11/25.
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import GoogleSignInSwift
import GoogleSignIn


class AuthenticationManager {
    
    // Custom log levels
    enum LogLevel {
        case info
        case warning
        case error
    }
    
    // Function to log messages
    public func log(message: String, level: LogLevel) {
        switch level {
        case .info:
            print("ℹ️ INFO: \(message)")
        case .warning:
            print("⚠️ WARNING: \(message)")
        case .error:
            print("❌ ERROR: \(message)")
        }
    }

    /// Handles authentication using a given credential (Google, Facebook, etc.)
    func handleAuthentication(with credential: AuthCredential, completion: @escaping (Result<Seas_3.User, Error>) -> Void) {
        // Log current user (if any)
        if let currentUser = Auth.auth().currentUser {
            self.log(message: "Currently signed in as \(currentUser.uid)", level: .info)
        } else {
            self.log(message: "No user currently authenticated. Please log in first.", level: .warning)
        }
        
        self.log(message: "Attempting to authenticate with Firebase using provided credential.", level: .info)

        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                self.log(message: "Error authenticating with Firebase: \(error.localizedDescription)", level: .error)

                if let errorCode = AuthErrorCode.Code(rawValue: (error as NSError).code) {
                    // Handle 'account exists with different credential'
                    if errorCode == .accountExistsWithDifferentCredential,
                       let email = (error as NSError).userInfo[AuthErrorUserInfoEmailKey] as? String {

                        self.log(message: "Fetching sign-in methods for \(email)", level: .info)
                        
                        // Skipping sign-in methods check due to email enumeration protection
                        self.log(message: "Email enumeration protection may be enabled — proceeding with password prompt", level: .warning)

                        self.promptForEmailPassword(email: email) { password in
                            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                                if let error = error {
                                    self.log(message: "Error signing in with password: \(error.localizedDescription)", level: .error)
                                    completion(.failure(error))
                                    return
                                }

                                guard let signedInUser = result?.user else {
                                    self.log(message: "No Firebase user after password sign-in", level: .error)
                                    completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                                    return
                                }

                                signedInUser.link(with: credential) { linkResult, linkError in
                                    if let linkError = linkError {
                                        self.log(message: "Failed to link credential: \(linkError.localizedDescription)", level: .error)
                                        completion(.failure(linkError))
                                    } else if let linkedUser = linkResult?.user {
                                        self.log(message: "Successfully linked credentials for \(linkedUser.uid)", level: .info)
                                        self.createUserFromFirebaseUser(linkedUser, completion: completion)
                                    } else {
                                        self.log(message: "Link result is nil", level: .error)
                                        completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                                    }
                                }
                            }
                        }
                        return
                    }
                }

                // Handle other errors
                completion(.failure(error))
                return
            }
            
            // Successful authentication
            self.log(message: "Authenticated with Firebase successfully.", level: .info)

            guard let firebaseUser = result?.user else {
                self.log(message: "No Firebase user found after successful authentication.", level: .error)
                completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                return
            }
            
            
            // 👉 ADD THIS LINE:
            print("✅ Firebase User UID: \(firebaseUser.uid)")
            
            self.log(message: "Creating user from Firebase data.", level: .info)
            self.createUserFromFirebaseUser(firebaseUser, completion: completion)
        }
    }




    /// Links an authentication credential to an existing Firebase user
    private func linkCredential(_ credential: AuthCredential, to user: FirebaseAuth.User, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        user.link(with: credential) { result, error in
            if let error = error {
                self.handleFirebaseError(error, user: user, credential: credential) { authResult in
                    switch authResult {
                    case .success(let updatedUser):
                        completion(.success(updatedUser))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                return
            }
            
            guard let linkedUser = result?.user else {
                self.log(message: "No Firebase user found after linking.", level: .error)
                completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                return
            }
            
            completion(.success(linkedUser))
        }
    }

    /// Converts Firebase User into a Seas_3.User model
    func createUserFromFirebaseUser(_ firebaseUser: FirebaseAuth.User, completion: @escaping (Result<Seas_3.User, Error>) -> Void) {
        let appUser = Seas_3.User(
            email: firebaseUser.email ?? "",
            userName: firebaseUser.displayName ?? "",
            name: "",
            passwordHash: Data(),
            salt: Data(),
            iterations: 0,
            isVerified: firebaseUser.isEmailVerified,
            belt: nil,
            verificationToken: nil,
            userID: firebaseUser.uid
        )
        
        completion(.success(appUser))
    }


    /// Handles Firebase authentication errors
    private func handleFirebaseError(_ error: Error, user: FirebaseAuth.User?, credential: AuthCredential, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        if let errorCode = AuthErrorCode.Code(rawValue: (error as NSError).code) {
            switch errorCode {
            case .accountExistsWithDifferentCredential:
                // Handle account exists with different credential
                self.log(message: "Account exists with different credential", level: .error)
                // Add your code here to handle this case
            default:
                self.log(message: "Firebase Auth Error: \(error.localizedDescription)", level: .error)
                completion(.failure(error))
            }
        } else {
            self.log(message: "Unknown Firebase Auth Error: \(error.localizedDescription)", level: .error)
            completion(.failure(error))
        }
    }

    /// Handles account linking when an account with the same email exists but uses a different provider
    private func handleAccountExistsWithDifferentCredential(user: FirebaseAuth.User, existingCredential: AuthCredential, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        // Extract email from credential
        guard let email = user.email else {
            self.log(message: "Unable to retrieve email for existing account", level: .error)
            completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
            return
        }
        
        // Check if email is empty
        if email.isEmpty {
            self.log(message: "Email is empty", level: .error)
            completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
            return
        }
        
        // Prompt the user to sign in with their existing credentials
        self.promptForEmailPassword(email: email) { password in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    self.log(message: "Error signing in with existing credential: \(error.localizedDescription)", level: .error)
                    completion(.failure(error))
                    return
                }
                
                guard let signedInUser = result?.user else {
                    self.log(message: "Error retrieving signed-in user.", level: .error)
                    completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                    return
                }
                
                // Link the new credential to the user's account
                signedInUser.link(with: existingCredential) { linkResult, linkError in
                    if let linkError = linkError {
                        self.log(message: "Error linking credentials: \(linkError.localizedDescription)", level: .error)
                        completion(.failure(linkError))
                    } else {
                        self.log(message: "Successfully linked credentials for user \(signedInUser.uid)", level: .info)
                        completion(.success(signedInUser))
                    }
                }
            }
        }
    }

    /// Helper function to prompt the user for their password (simulated here)
    public func promptForEmailPassword(email: String, completion: @escaping (String) -> Void) {
        self.log(message: "Prompting user for password for email: \(email)", level: .info)
        print("Email: \(email)")
        
        // Add a log message to check if this function is being called
        self.log(message: "promptForEmailPassword function called", level: .info)
        
        // Present a UI component to collect the user's password
        let alertController = UIAlertController(title: "Enter Password", message: "Please enter your password for \(email)", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let submitAction = UIAlertAction(title: "Submit", style: .default) { _ in
            if let password = alertController.textFields?.first?.text, !password.isEmpty {
                completion(password)
            } else {
                self.log(message: "No password entered.", level: .warning)
                completion("")
            }
        }

        
        alertController.addAction(cancelAction)
        alertController.addAction(submitAction)
        
        // Present the alert controller
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            
            DispatchQueue.main.async {
                rootViewController.present(alertController, animated: true) {
                    print("Alert controller presented")
                }
            }
        } else {
            self.log(message: "No root view controller found", level: .error)
        }

    }
}
