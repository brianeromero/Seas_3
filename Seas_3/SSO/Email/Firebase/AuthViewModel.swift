// AuthViewModel.swift
// Seas_3
//
// Created by Brian Romero on 10/22/24.

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

enum CoreDataError: Error, LocalizedError {
    case fetchError
    case saveError
    
    var errorDescription: String? {
        switch self {
        case .fetchError:
            return "Core Data fetch error."
        case .saveError:
            return "Core Data save error."
        }
    }
}

class AuthViewModel: ObservableObject {
    // Create a shared instance of AuthViewModel
    static let shared = AuthViewModel()
    @Published var usernameOrEmail: String = ""
    @Published var password: String = ""
    @Published var isSignInEnabled: Bool = false
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

    // MARK: Create Firebase user with email/password
    @MainActor
    func createUser(withEmail email: String, password: String, userName: String, name: String) async throws {
        guard !email.isEmpty, !password.isEmpty, !userName.isEmpty, !name.isEmpty else {
            throw AuthError.invalidInput
        }
        
        // Create user in Firebase
        let authResult = try await auth.createUser(withEmail: email, password: password)
        print("Firebase user created successfully.")

        // Check if user already exists in Core Data
        let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        let existingUsers: [UserInfo] = try await self.context.perform {
            try self.context.fetch(request)
        }
        
        if let existingUser = existingUsers.first {
            // Update existing Core Data user
            existingUser.userName = userName
            existingUser.name = name
            try context.save()
            print("User already exists. Updated existing user.")
            return
        }
        
        // Add new user to Core Data
        try addUserToCoreData(with: authResult.user.uid, email: email, userName: userName, name: name)

        // Create Firestore document with user ID as the document ID
        let userRef = Firestore.firestore().collection("users").document(authResult.user.uid)
        do {
            try await userRef.setData([
                "email": email,
                "userName": userName,
                "name": name,
                "userID": authResult.user.uid,
                "isVerified": false,
                "createdAt": Timestamp(),
                "lastLogin": Timestamp()
            ], merge: true)
        } catch let error as NSError {
            if error.domain == FirestoreErrorDomain && error.code == FirestoreErrorCode.permissionDenied.rawValue {
                print("Insufficient permissions to create Firestore document.")
                self.errorMessage = "Error creating user: Missing permissions. Please try logging in again."
            } else {
                print("Error creating Firestore document: \(error.localizedDescription)")
                self.errorMessage = "Error creating user: \(error.localizedDescription)"
            }
        }

        // Send Firebase verification email
        authResult.user.sendEmailVerification { [weak self] error in
            if let error = error {
                print("Firebase verification email error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Error sending Firebase verification email: \(error.localizedDescription)"
                }
            }
        }
        
        // Send custom verification email
        let success = await emailManager.sendVerificationToken(to: email, userName: userName, password: password)
        if success {
            self.showVerificationAlert = true
        } else {
            self.errorMessage = "Error sending verification email."
        }
    }

    // New method to add user to Core Data
    private func addUserToCoreData(with userID: String, email: String, userName: String, name: String) throws {
        let newUser = UserInfo(context: context)
        newUser.userID = userID
        newUser.userName = userName
        newUser.email = email
        newUser.name = name
        newUser.isVerified = false // Set this based on your app's logic for new users

        // Hash the password
        let hashedPassword = try hashPasswordPbkdf(password)

        // Convert hash, salt, and iterations safely
        guard let passwordHashData = hashedPassword.hash.base64EncodedString().data(using: .utf8),
              let saltData = hashedPassword.salt.base64EncodedString().data(using: .utf8) else {
            throw AuthError.firebaseError(NSError(domain: "Hash conversion error", code: -1, userInfo: nil))
        }

        newUser.passwordHash = passwordHashData
        newUser.salt = saltData
        newUser.iterations = Int64(hashedPassword.iterations)

        // Save to Core Data
        do {
            try context.save()
            print("User successfully saved to Core Data")
        } catch {
            print("Failed to save user to Core Data: \(error)")
            throw error // Handle the error as needed
        }
    }


    // Handle email verification response
    func handleEmailVerificationResponse() async {
        guard let user = Auth.auth().currentUser else { return }

        do {
            try await user.reload() // Reload user data from Firebase
            
            // Check if the email is verified
            if user.isEmailVerified {
                print("Email verified successfully")
                // Update user's verification status
                try await updateVerificationStatus(for: user.email!, isVerified: true)

                // Log current user verification status after update
                print("User verification status after update: \(self.currentUser?.isVerified ?? false)")
                
                currentUser?.isVerified = true
            } else {
                print("Email not verified yet.")
            }
        } catch {
            print("Error reloading user: \(error.localizedDescription)")
            errorMessage = "Error reloading user."
        }
    }
    
    // Update user's verification status in Core Data and Firestore
    func updateVerificationStatus(for email: String, isVerified: Bool) async throws {
        // Log the current user verification status before updating
        print("User verification status before update: \(self.currentUser?.isVerified ?? false)")

        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "email == %@", email)

        do {
            let users = try context.fetch(request)
            if let user = users.first {
                user.isVerified = isVerified
                try context.save()
                print("User verification status updated for: \(user.email)")
            } else {
                print("User not found in Core Data for email: \(email)")
            }
        } catch {
            throw error
        }

        // Update Firestore
        let userRef = Firestore.firestore().collection("users").document(email)
        do {
            try await userRef.setData(["isVerified": isVerified], merge: true)
            print("Firestore verification status updated for: \(email)")
        } catch let error as NSError {
            if error.domain == FirestoreErrorDomain && error.code == 7 {
                print("Missing or insufficient permissions.")
                // Handle permission error
            } else {
                print("Error updating Firestore verification status: \(error.localizedDescription)")
            }
            throw error // Throw the error to propagate it up
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
        seasUser.userID = firebaseUser.uid // Use Firebase's User UID
        
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
        seasUser.userID = firebaseUser.uid
        seasUser.isVerified = false

        return seasUser
    }

    // Send sign-in link (passwordless)
    func sendSignInLink(toEmail email: String) async {
        print("Attempting to send sign-in link to \(email)...")
        print("Sending sign-in link to \(email)...")
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "http://mfinderbjj.rf.gd/firebaseSignInLink.html")
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier!)
        actionCodeSettings.setAndroidPackageName("com.example.android", installIfNotAvailable: false, minimumVersion: "12")

        do {
            try await Auth.auth().sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)
            print("Sign-in link sent successfully to \(email)")
        } catch {
            print("Error sending sign-in link to \(email): \(error.localizedDescription)")
            errorMessage = "Error sending sign-in link. Please try again."
        }
    }
    
    func fetchUserByFirebaseUID(firebaseUID: String) -> UserInfo? {
        print("Fetching user with Firebase UID: \(firebaseUID)")
        
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "userID == %@", firebaseUID)
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("Error fetching user by Firebase UID \(firebaseUID): \(error.localizedDescription)")
            return nil
        }
    }


    func signInUser(with identifier: String, password: String) async throws {
        print("Signing in user \(identifier)...")
        
        do {
            // Fetch user record
            guard let user = try await fetchUser(identifier) else {
                print("User not found for identifier: \(identifier)")
                throw NSError(domain: "User not found", code: 404, userInfo: nil)
            }
            
            // Sign in with fetched email
            let authResult = try await auth.signIn(withEmail: user.email, password: password)
            print("User signed in successfully with email: \(user.email)")
            
            // Update Firestore with login event
            let userRef = Firestore.firestore().collection("users").document(user.email)
            try await userRef.updateData(["lastLogin": Timestamp()])
            
            // Map Firebase user to local user model
            let currentUser = try await mapFirebaseUserToSeasUser(
                firebaseUser: authResult.user,
                userName: user.userName,
                name: user.name
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.userSession = authResult.user
                self?.currentUser = currentUser
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                switch error {
                case AuthErrorCode.invalidEmail:
                    self?.errorMessage = "Invalid email address."
                case AuthErrorCode.wrongPassword:
                    self?.errorMessage = "Incorrect password."
                default:
                    self?.errorMessage = "Sign-in failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Fetch user by email from Firebase
    private func fetchUserByEmail(_ email: String) async -> Result<User?, Error> {
        if let firebaseUser = Auth.auth().currentUser {
            let userName = "DefaultUserName" // Replace this with actual logic to get the username
            let name = "DefaultName" // Replace this with actual logic to get the name
            let user = User(from: firebaseUser, userName: userName, name: name) // Use the custom initializer
            return .success(user)
        } else {
            return .failure(NSError(domain: "User not found", code: 404, userInfo: nil))
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

    func verifyUserAndFetch(email: String) async {
        let result = await fetchUserByEmail(email)
        switch result {
        case .success(let user):
            if let user = user {
                print("User is verified: \(user.isVerified)")
            }
        case .failure(let error):
            print("Error fetching user: \(error.localizedDescription)")
        }
    }

    // Manually verify user
    func manuallyVerifyUser(email: String) async throws -> Bool {
        // Update user's verification status in Core Data
        try await updateVerificationStatus(for: email, isVerified: true)
        
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

    private func fetchUser(_ usernameOrEmail: String) async throws -> User? {
        // Check if input is email
        if ValidationUtility.validateEmail(usernameOrEmail) == nil {
            // Use `get` to retrieve only the User object, not Result
            switch await fetchUserByEmail(usernameOrEmail) {
            case .success(let user):
                return user
            case .failure(let error):
                throw error
            }
        } else {
            // Fetch user by username from Firebase (requires custom Firebase implementation)
            return try await fetchUserByUsername(usernameOrEmail)
        }
    }

    // Fetch user by username from Firebase
    private func fetchUserByUsername(_ username: String) async throws -> User? {
        let firestore = Firestore.firestore()
        let query = firestore.collection("users").whereField("userName", isEqualTo: username)
        do {
            let querySnapshot = try await query.getDocuments()
            if let document = querySnapshot.documents.first {
                let userData = document.data()
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: userData)
                    return try JSONDecoder().decode(User.self, from: jsonData)
                } catch {
                    print("Error decoding user data: \(error.localizedDescription)")
                    throw error
                }
            } else {
                throw NSError(domain: "User not found", code: 404, userInfo: nil)
            }
        } catch {
            throw error
        }
    }
}
