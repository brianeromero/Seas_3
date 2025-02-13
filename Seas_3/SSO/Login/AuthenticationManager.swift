//
//  AuthenticationManager.swift
//  Seas_3
//
//  Created by Brian Romero on 2/11/25.
//

import Foundation
import Firebase
import FirebaseAuth
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
        // Check if there is already a user signed in
        if let currentUser = Auth.auth().currentUser {
            self.log(message: "Currently signed in as \(currentUser.uid)", level: .info)
            print("Currently signed in as \(currentUser.uid)") // Additional print for debugging
        } else {
            self.log(message: "No user currently authenticated. Please log in first.", level: .warning)
            print("No user currently authenticated. Please log in first.") // Additional print for debugging
        }
        
        self.log(message: "Attempting to authenticate with Firebase using provided credential.", level: .info)
        print("Attempting to authenticate with Firebase using provided credential: \(credential)") // Log the credential for debugging
        
        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                self.log(message: "Error authenticating with Firebase: \(error.localizedDescription)", level: .error)
                print("Error authenticating with Firebase: \(error.localizedDescription)") // Additional print for debugging
                
                let errorCode = AuthErrorCode(rawValue: (error as NSError).code)
                print("Firebase error code: \(errorCode?.rawValue ?? -1)") // Print the error code for additional debugging
                
                // Handle the case when the account exists with a different credential
                if errorCode == .accountExistsWithDifferentCredential {
                    self.log(message: "Account exists with different credential. Attempting to link credentials.", level: .info)
                    print("Account exists with different credential. Attempting to link credentials.") // Additional print for debugging
                    
                    guard let currentUser = Auth.auth().currentUser else {
                        self.log(message: "1No Firebase user found.", level: .error)
                        print("No Firebase user found during credential linking.") // Additional print for debugging
                        completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                        return
                    }
                    
                    print("Attempting to link credentials with current user: \(currentUser.uid)") // Log user UID for linking
                    
                    self.handleAccountExistsWithDifferentCredential(user: currentUser, existingCredential: credential) { result in
                        switch result {
                        case .success(let firebaseUser):
                            self.createUserFromFirebaseUser(firebaseUser) { result in
                                switch result {
                                case .success(let user):
                                    self.log(message: "Successfully created user from Firebase data.", level: .info)
                                    print("Successfully created user from Firebase data: \(user)") // Additional print for debugging
                                    completion(.success(user))
                                case .failure(let error):
                                    self.log(message: "Error creating user from Firebase data: \(error.localizedDescription)", level: .error)
                                    print("Error creating user from Firebase data: \(error.localizedDescription)") // Additional print for debugging
                                    completion(.failure(error))
                                }
                            }
                        case .failure(let error):
                            self.log(message: "Error linking credentials: \(error.localizedDescription)", level: .error)
                            print("Error linking credentials: \(error.localizedDescription)") // Additional print for debugging
                            completion(.failure(error))
                        }
                    }
                    return
                }
                
                // For other errors, just return the error
                print("Returning error: \(error.localizedDescription)") // Additional print for debugging
                completion(.failure(error))
                return
            }
            
            self.log(message: "Authenticated with Firebase successfully.", level: .info)
            print("Authenticated with Firebase successfully.") // Additional print for debugging
            
            guard let firebaseUser = result?.user else {
                self.log(message: "2No Firebase user found.", level: .error)
                print("No Firebase user found after successful authentication.") // Additional print for debugging
                completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                return
            }
            
            self.log(message: "Creating user from Firebase data.", level: .info)
            print("Creating user from Firebase data: \(firebaseUser)") // Log Firebase user info for debugging
            
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
    ///
    func createUserFromFirebaseUser(_ firebaseUser: FirebaseAuth.User, completion: @escaping (Result<Seas_3.User, Error>) -> Void) {
        let userID = UUID(uuidString: firebaseUser.uid) ?? UUID()
        
        let userInfo = UserInfo()
        userInfo.email = firebaseUser.email ?? ""
        userInfo.userName = firebaseUser.displayName ?? ""
        userInfo.name = ""
        userInfo.passwordHash = Data()
        userInfo.salt = Data()
        userInfo.iterations = 0
        userInfo.isVerified = firebaseUser.isEmailVerified
        userInfo.userID = userID.uuidString
        userInfo.belt = nil
        userInfo.verificationToken = nil
        
        let appUser = Seas_3.User(from: userInfo)
        completion(.success(appUser))
    }

    /// Handles Firebase authentication errors
    private func handleFirebaseError(_ error: Error, user: FirebaseAuth.User?, credential: AuthCredential, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        let errorCode = AuthErrorCode(rawValue: (error as NSError).code)
        
        switch errorCode {
        case .accountExistsWithDifferentCredential:
            guard let currentUser = Auth.auth().currentUser else {
                self.log(message: "3No Firebase user found.", level: .error)
                completion(.failure(NSError(domain: "AuthenticationError", code: 0, userInfo: nil)))
                return
            }
            
            self.handleAccountExistsWithDifferentCredential(user: currentUser, existingCredential: credential, completion: completion)
            
        default:
            self.log(message: "Firebase Auth Error: \(error.localizedDescription)", level: .error)
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
            if let password = alertController.textFields?.first?.text {
                completion(password)
            } else {
                self.log(message: "Password entry failed.", level: .error)
                completion("")
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(submitAction)
        
        // Present the alert controller
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alertController, animated: true) {
                print("Alert controller presented")
            }
        } else {
            self.log(message: "No root view controller found", level: .error)
        }
    }
}
