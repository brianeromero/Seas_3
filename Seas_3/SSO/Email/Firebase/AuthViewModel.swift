//  AuthViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 10/22/24.
//

import Foundation
import Firebase
import FirebaseAuth
import CryptoSwift
import CoreData
import Combine

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: Seas_3.User?
    @Published var errorMessage: String = ""
    @Published var showVerificationAlert: Bool = false
    @Published var isUserProfileActive: Bool = false
    @Published var formState: FormState = FormState()

    private let auth = Auth.auth()
    private let context: NSManagedObjectContext
    private let emailManager: UnifiedEmailManager

    init(managedObjectContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext, emailManager: UnifiedEmailManager = .shared) {
        self.context = managedObjectContext
        self.emailManager = emailManager
    }

    // Create Firebase user with email/password
    @MainActor
    func createUser(withEmail email: String, password: String, username: String, name: String) async -> Result<(), Error> {
        do {
            // Validate input
            guard !email.isEmpty, !password.isEmpty else {
                throw AuthError.invalidInput
            }
            
            // Create user
            let authResult = try await auth.createUser(withEmail: email, password: password)
            
            print("App Check token successful")
            
            // Map Firebase user to SeasUser
            _ = try await mapFirebaseUserToSeasUser(firebaseUser: authResult.user, username: username, name: name)
            
            // Save user to Core Data
            try await context.perform {
                try self.context.save()
            }
            
            // Send Firebase verification email
            authResult.user.sendEmailVerification(completion: { [weak self] error in
                if let error = error {
                    print("Firebase verification email error: \(error.localizedDescription)")
                    self?.errorMessage = "Error sending Firebase verification email."
                }
            })
            
            // Send custom verification email
            emailManager.sendVerificationToken(to: email, userName: username) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.showVerificationAlert = true
                    } else {
                        self?.errorMessage = "Error sending verification email."
                    }
                }
            }
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    // Define AuthError enum
    enum AuthError: Error, LocalizedError {
        case invalidInput
        case firebaseError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidInput:
                return "Email and password are required."
            case .firebaseError(let error):
                return error.localizedDescription
            }
        }
    }
        
    func mapFirebaseUserToSeasUser(firebaseUser: FirebaseAuth.User, username: String, name: String) async throws -> Seas_3.User {
        let seasUser = try Seas_3.User(from: context as! Decoder)
        seasUser.email = firebaseUser.email ?? ""
        seasUser.username = username
        seasUser.name = name
        
        // Hash the password
        let hashedPassword = try hashPasswordPbkdf(formState.password)

        // Convert hash, salt, and iterations to the appropriate types
        let passwordHash = hashedPassword.hash.base64EncodedString()
        let salt = hashedPassword.salt.base64EncodedString()
        let iterations = hashedPassword.iterations

        seasUser.passwordHash = passwordHash.data(using: .utf8)!
        seasUser.salt = salt.data(using: .utf8)!
        seasUser.iterations = Int64(iterations)
        seasUser.userID = UUID()
        seasUser.isVerified = false

        return seasUser
    }

    // Send sign-in link (passwordless)
    internal func sendSignInLink(toEmail email: String) async {
        print("Sending sign-in link to \(email)...")
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "http://mfinderbjj.rf.gd/firebaseSignInLink.html")
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier!)
        actionCodeSettings.setAndroidPackageName("com.example.android", installIfNotAvailable: false, minimumVersion: "12")

        do {
            try await Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)
        } catch {
            errorMessage = "Error sending sign-in link. Please try again."
        }
    }


    private func signInUser(to email: String, password: String) async {
        print("Signing in user \(email)...")
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            
            print("App Check token successful")
            
            // Directly access the user property of AuthDataResult
            let _ = try await mapFirebaseUserToSeasUser(firebaseUser: authResult.user, username: formState.username, name: formState.name)
        } catch {
            switch error {
            case AuthErrorCode.secondFactorRequired:
                errorMessage = "App Check failed. Please try again."
            default:
                errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }
        }
    }
}
