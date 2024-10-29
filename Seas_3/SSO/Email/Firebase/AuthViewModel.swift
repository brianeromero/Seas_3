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

class AuthViewModel: ObservableObject {
    // Create a shared instance of AuthViewModel
    static let shared = AuthViewModel()

    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: UserInfo?
    @Published var errorMessage: String = ""
    @Published var showVerificationAlert: Bool = false
    @Published var isUserProfileActive: Bool = false
    @Published var formState: FormState = FormState()

    private let auth = Auth.auth()
    public let context: NSManagedObjectContext
    private let emailManager: UnifiedEmailManager

    public init(managedObjectContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext, emailManager: UnifiedEmailManager = .shared) {
        self.context = managedObjectContext
        self.emailManager = emailManager
    }

    // Create Firebase user with email/password
    @MainActor
    func createUser(withEmail email: String, password: String, userName: String, name: String) async -> Result<(), Error> {
        do {
            // Validate input
            guard !email.isEmpty, !password.isEmpty else {
                throw AuthError.invalidInput
            }
            
            // Create user
            let authResult = try await auth.createUser(withEmail: email, password: password)
            
            print("App Check token successful")
            
            // Map Firebase user to SeasUser
            self.currentUser = try await mapFirebaseUserToSeasUser(firebaseUser: authResult.user, userName: formState.userName, name: formState.name)
            
            // Cache currentUser
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
            emailManager.sendVerificationToken(to: email, userName: userName, userPassword: password) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.showVerificationAlert = true
                    } else {
                        self?.errorMessage = "Error sending verification email."
                    }
                }
            }
            
            // Update user's verification status in Firestore
            try updateVerificationStatus(for: authResult.user.email!, isVerified: false)

            return .success(())
        } catch {
            return .failure(error)
        }
    }
    

    // Handle email verification response
    func handleEmailVerificationResponse() async {
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            try await user.reload()
            
            // Check if email is verified
            if user.isEmailVerified {
                print("Email verified successfully")
                
                // Update user's isVerified status in Core Data
                try updateVerificationStatus(for: user.email!, isVerified: true)
                
                // Update userSession
                userSession = user
                
                // Update currentUser
                if !formState.userName.isEmpty, !formState.name.isEmpty {
                    currentUser = try await mapFirebaseUserToSeasUser(firebaseUser: user, userName: formState.userName, name: formState.name)
                } else {
                    print("Username or name is missing")
                }
            } else {
                print("Email not verified")
            }
        } catch {
            print("Error reloading user: \(error.localizedDescription)")
            errorMessage = "Error reloading user."
        }
    }
    
    
    
    // Update user's verification status in Core Data and Firestore
    func updateVerificationStatus(for email: String, isVerified: Bool) throws {
        // Update Core Data
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "email == %@", email)

        var userInfo: UserInfo?
        do {
            let users = try context.fetch(request)
            userInfo = users.first
            if let user = userInfo {
                user.isVerified = isVerified
                try context.save()
                print("User verification status updated for: \(user.email)")
            }
        } catch {
            throw error
        }
        
        // Update Firestore
        Firestore.firestore().collection("users").document(email).setData(["isVerified": isVerified], merge: true) { error in
            if let error = error {
                print("Error updating Firestore verification status: \(error.localizedDescription)")
            } else {
                print("Firestore verification status updated for: \(email)")
            }
        }
    }

    
    func mapFirebaseUserToSeasUser(firebaseUser: FirebaseAuth.User, userName: String, name: String) async throws -> UserInfo {
        // Use Core Data's context to create a new UserInfo
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "UserInfo", in: context) else {
            throw AuthError.firebaseError(NSError(domain: "Entity description not found", code: -1, userInfo: nil))
        }

        let seasUser = UserInfo(entity: entityDescription, insertInto: context)
        
        seasUser.email = firebaseUser.email ?? ""
        seasUser.userName = userName
        seasUser.name = name
        
        // Hash the password
        let hashedPassword = try hashPasswordPbkdf(formState.password)
        
        // Convert hash, salt, and iterations safely
        guard let passwordHashData = hashedPassword.hash.base64EncodedString().data(using: .utf8),
              let saltData = hashedPassword.salt.base64EncodedString().data(using: .utf8) else {
            throw AuthError.firebaseError(NSError(domain: "Hash conversion error", code: -1, userInfo: nil))
        }

        seasUser.passwordHash = passwordHashData
        seasUser.salt = saltData
        seasUser.iterations = Int64(hashedPassword.iterations)
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
            
            userSession = authResult.user
            currentUser = try await mapFirebaseUserToSeasUser(firebaseUser: authResult.user, userName: formState.userName, name: formState.name)
        } catch {
            switch error {
            case AuthErrorCode.secondFactorRequired:
                errorMessage = "App Check failed. Please try again."
            case AuthErrorCode.invalidEmail:
                errorMessage = "Invalid email address."
            case AuthErrorCode.wrongPassword:
                errorMessage = "Incorrect password."
            default:
                errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }
        }
    }
    
    func fetchUserByEmail(email: String, completion: @escaping (UserInfo?, Error?) -> Void) {
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        let normalizedEmail = email.lowercased() // Normalize for comparison
        request.predicate = NSPredicate(format: "email == %@", normalizedEmail)
        
        print("Fetching user with email: \(normalizedEmail)") // Debugging line
        
        do {
            let userInfo = try context.fetch(request).first
            print("Fetched user: \(userInfo?.email ?? "None")") // Debugging line
            completion(userInfo, nil)
        } catch {
            completion(nil, error)
        }
    }

    
    func logAllUsers() {
        let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        
        do {
            let users = try context.fetch(request)
            for user in users {
                print("User: \(user.email)")
            }
        } catch {
            print("Error fetching users: \(error.localizedDescription)")
        }
    }

    func verifyUserAndFetch(email: String) {
        fetchUserByEmail(email: email) { userInfo, error in
            if let user = userInfo {
                print("User is verified: \(user.isVerified)")
            } else if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
            }
        }
    }
    
    // Manually verify user
    func manuallyVerifyUser(email: String) async throws -> Bool {
        // Update user's verification status in Core Data
        try updateVerificationStatus(for: email, isVerified: true)
        
        // Update user's verification status in Firestore
        let firestore = Firestore.firestore()
        let userRef = firestore.collection("users").document(email)
        
        do {
            try await userRef.setData(["isVerified": true], merge: true)
            print("Firestore verification status updated for: \(email)")
            return true
        } catch {
            throw error
        }
    }
}
