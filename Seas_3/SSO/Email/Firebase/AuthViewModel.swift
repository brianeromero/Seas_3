// AuthViewModel.swift
// Seas_3
//
// Created by Brian Romero on 10/22/24.

import Foundation
import Firebase
@preconcurrency import FirebaseAuth
import CryptoSwift
import CoreData
import Combine

// Define AuthError enum
enum AuthError: Error, LocalizedError {
    case invalidInput
    case firebaseError(Error)
    case coreDataError(Error)
    case userNotAuthenticated
    case passwordsDoNotMatch
    case invalidEmail
    case unknownError
    case notSignedIn
    case userAlreadyExists
    case invalidStoredPassword


    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Email and password are required."
        case .firebaseError(let error):
            return error.localizedDescription
        case .coreDataError(let error):
            return error.localizedDescription
        case .userNotAuthenticated:
            return "User not authenticated."
        case .passwordsDoNotMatch:
            return "Passwords do not match."
        case .invalidEmail:
            return "Email is invalid."
        case .notSignedIn:
            return "User is not signed in."
        case .unknownError:
            return "Unknown Error, pleaes reach out to email: mfinder.bjj@gmail.com"
        case .userAlreadyExists:
            return "User Already Exists; pleaes email: mfinder.bjj@gmail.com in order to be reset"
        case .invalidStoredPassword:
            return "Password stored is invalid"
        }
    }
}

// Define error domains and codes
enum ErrorDomain: String {
    case auth
    case coreData
}

enum ErrorCode: Int {
    case invalidInput = 400
    case userNotFound = 404
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

    public init(managedObjectContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
                emailManager: UnifiedEmailManager = .shared) {
        self.context = managedObjectContext
        self.emailManager = emailManager
    }


    // MARK: Create Firebase user with email/password
    @MainActor
    func createUser(withEmail email: String, password: String, userName: String, name: String, belt: String?) async throws {
        guard !email.isEmpty, !password.isEmpty, !userName.isEmpty, !name.isEmpty else {
            throw AuthError.invalidInput
        }
        
        let normalizedEmail = email.lowercased()
        
        // Ensure the user doesn't exist in either Core Data or Firestore before proceeding
        if await userAlreadyExists() {
            throw AuthError.userAlreadyExists
        }
        
        // Proceed with user creation in Firestore and Core Data
        do {
            let authResult = try await auth.createUser(withEmail: normalizedEmail, password: password)
            
            // Create user in Core Data if not found
            try await createUserInCoreData(authResult.user.uid, email: normalizedEmail, userName: userName, name: name, belt: belt)
            
            // Create Firestore document
            try await createFirestoreDocument(for: authResult.user.uid, email: normalizedEmail, userName: userName, name: name, belt: belt)

            // Send verification emails
            try await sendVerificationEmail(to: normalizedEmail)
            try await sendCustomVerificationEmail(to: normalizedEmail, userName: userName, password: password)
            
        } catch {
            throw AuthError.firebaseError(error)
        }
    }

    func createUserInCoreData(_ userId: String, email: String, userName: String, name: String, belt: String?) async throws {
        // Check if the user already exists in Core Data
        let result = await fetchUserByEmail(email)
        
        switch result {
        case .success(let existingUser):
            if let existingUser = existingUser {
                // Handle the case where the user already exists in Core Data
                try updateUser(existingUser, with: userName, name: name)
            } else {
                // Add the user to Core Data if not found
                try addUserToCoreData(with: userId, email: email, userName: userName, name: name, belt: belt)
            }
            
        case .failure(let error):
            // Handle the error
            print("Error fetching user: \(error.localizedDescription)")
            throw error
        }
    }


    func userAlreadyExists() async -> Bool {
        // Check if the user exists in Core Data first
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ OR userName == %@", formState.email, formState.userName)

        do {
            let existingUsers = try context.fetch(fetchRequest)
            if !existingUsers.isEmpty {
                if existingUsers.first?.email == formState.email {
                    errorMessage = "A user with this email address already exists."
                } else {
                    errorMessage = "A user with this username already exists."
                }
                self.showVerificationAlert = true
                return true
            }
        } catch {
            print("Error checking user existence in Core Data: \(error.localizedDescription)")
            errorMessage = "Error checking user existence."
            return true
        }

        // Check if the user exists in Firestore
        return await userAlreadyExistsInFirestore()
    }

    
    func userAlreadyExistsInFirestore() async -> Bool {
        let firestore = Firestore.firestore()
        let query = firestore.collection("users").whereField("email", isEqualTo: formState.email).whereField("userName", isEqualTo: formState.userName)

        do {
            let querySnapshot = try await query.getDocuments()
            return !querySnapshot.documents.isEmpty
        } catch {
            print("Error checking user existence in Firestore: \(error.localizedDescription)")
            errorMessage = "Error checking user existence."
            return true
        }
    }
    
    // Resets all the profile form fields
    func resetProfileForm() {
        self.usernameOrEmail = ""
        self.password = ""
        self.errorMessage = ""
        self.formState = FormState() // Reset formState as well
    }

    // Add this method to AuthViewModel
    func logoutUser() async throws {
        do {
            try auth.signOut()
            await MainActor.run {
                userSession = nil
                currentUser = nil
            }
        } catch {
            throw AuthError.firebaseError(error)
        }
    }



    // Ensure fetchUserByEmail is async
    func fetchUserByEmail(_ email: String) async -> Result<UserInfo?, Error> {
        // Perform your Core Data fetch and return a Result type
        do {
            let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "email == %@", email)
            
            let result = try context.fetch(fetchRequest)
            if let user = result.first {
                return .success(user)
            } else {
                return .success(nil)
            }
        } catch {
            return .failure(error)
        }
    }


    // Modify fetchUserByUsername
    private func fetchUserByUsername(_ username: String) async -> Result<UserInfo?, Error> {
        let firestore = Firestore.firestore()
        let query = firestore.collection("users").whereField("userName", isEqualTo: username)

        do {
            let querySnapshot = try await query.getDocuments()
            if let document = querySnapshot.documents.first {
                let userData = document.data()
                let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
                request.predicate = NSPredicate(format: "email == %@", userData["email"] as? String ?? "")
                
                let users = try await self.context.perform {
                    try self.context.fetch(request)
                }
                // Wrap the result in a Result type
                return .success(users.first)
            } else {
                return .failure(NSError(domain: "User not found", code: 404, userInfo: nil))
            }
        } catch {
            return .failure(error)
        }
    }

    
    private func updateUser(_ user: UserInfo, with userName: String, name: String) throws {
        user.userName = userName
        user.name = name
        try context.save()
    }

    private func createFirestoreDocument(for userID: String, email: String, userName: String, name: String, belt: String?) async throws {
        var userData: [String: Any] = [
            "email": email,
            "userName": userName,
            "name": name,
            "userID": userID,
            "isVerified": false,
            "createdAt": Timestamp(),
            "lastLogin": Timestamp()
        ]
        
        if let belt = belt {
            userData["belt"] = belt
        }
        
        let userRef = Firestore.firestore().collection("users").document(userID)
        try await userRef.setData(userData, merge: true)
    }



    private func sendVerificationEmail(to email: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.invalidInput
        }
        
        try await Task<Void, Error> {
            try await withCheckedThrowingContinuation { continuation in
                user.sendEmailVerification { error in
                    if let error = error {
                        continuation.resume(throwing: AuthError.firebaseError(error))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }.value
    }
    
    
    
    private func sendCustomVerificationEmail(to email: String, userName: String, password: String) async throws {
        let success = await emailManager.sendVerificationToken(to: email, userName: userName, password: password)
        if success {
            print("Custom verification email sent successfully.")
        } else {
            throw AuthError.firebaseError(NSError(domain: "Error sending custom verification email", code: -1, userInfo: nil))
        }
    }


    // New method to add user to Core Data
    private func addUserToCoreData(with userID: String, email: String, userName: String, name: String, belt: String?) throws {
        let hashPassword = HashPassword()
        let newUser = UserInfo(context: context)
        newUser.userID = userID
        newUser.userName = userName
        newUser.email = email
        newUser.name = name
        newUser.isVerified = false

        // Assign the optional belt if provided
        if let belt = belt {
            newUser.belt = belt
        }

        // Hash the password using the updated hashPasswordScrypt
        let hashedPassword = try hashPassword.hashPasswordScrypt(password)
        print("Password: \(password)")
        print("Salt: \(hashedPassword.salt)")
        print("Iterations: \(hashedPassword.iterations)")
        
        // Assign the raw Data directly to the Core Data properties (no Base64 conversion needed)
        newUser.passwordHash = hashedPassword.hash  // Store the hash as Data
        newUser.salt = hashedPassword.salt          // Store the salt as Data
        newUser.iterations = Int64(hashedPassword.iterations)  // Store iterations as Int64

        // Save to Core Data
        do {
            try context.save()
            print("User successfully saved to Core Data")
        } catch {
            print("Failed to save user to Core Data: \(error)")
            throw error // Rethrow or handle error accordingly
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
                print("User not found in Core Data")
            }
        } catch {
            print("Failed to fetch or save user in Core Data: \(error)")
            throw CoreDataError.saveError
        }

        let firestore = Firestore.firestore()
        let userRef = firestore.collection("users").document(email)
        try await userRef.updateData(["isVerified": isVerified])
    }

    func mapFirebaseUserToSeasUser(firebaseUser: FirebaseAuth.User, userName: String, name: String) async throws -> UserInfo {
        let hashPassword = HashPassword()
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
        let hashedPassword = try hashPassword.hashPasswordScrypt(formState.password)
        
        // Assign raw Data to Core Data properties (no Base64 encoding)
        seasUser.passwordHash = hashedPassword.hash // Store raw hash as Data
        seasUser.salt = hashedPassword.salt         // Store raw salt as Data
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

    // Refactor sign-in method to separate password verification and Firebase authentication
    func signInUser(with identifier: String, password: String) async throws {
        let hashPassword = HashPassword() // Add this line
        print("Signing in user \(identifier)...")
        
        // Fetch user from Core Data
        guard let user = try await fetchUser(identifier) else {
            print("User not found for identifier: \(identifier)")
            throw NSError(domain: ErrorDomain.auth.rawValue, code: ErrorCode.userNotFound.rawValue, userInfo: nil)
        }
        
        // Extract stored hash and salt from Core Data
        guard let storedSalt = Data(base64Encoded: user.salt),
              let storedHash = Data(base64Encoded: user.passwordHash) else {
            throw AuthError.invalidStoredPassword
        }

        // Debug the stored salt value
        print("Stored Salt: \(user.salt)")
        
        // Create a HashedPassword object from storedSalt and storedHash
        let storedHashedPassword = HashedPassword(hash: storedHash, salt: storedSalt, iterations: Int(user.iterations))

        // Verify password using SCRYPT
        guard try hashPassword.verifyPasswordScrypt(password, againstHash: storedHashedPassword) else {
            throw AuthError.passwordsDoNotMatch
        }

        // Proceed with Firebase authentication
        let authResult = try await auth.signIn(withEmail: user.email, password: password)
        
        // Update Firestore with last login timestamp
        try await updateFirestoreLoginTimestamp(for: user.email)
        
        // Map Firebase user to local user model
        let currentUser = try await mapFirebaseUserToSeasUser(firebaseUser: authResult.user, userName: user.userName, name: user.name)

        // Set session and current user state on main thread
        await MainActor.run {
            userSession = authResult.user
            self.currentUser = currentUser
        }
    }


    private func updateFirestoreLoginTimestamp(for email: String) async throws {
        let userRef = Firestore.firestore().collection("users").document(email)
        try await userRef.updateData(["lastLogin": Timestamp()])
    }
    
    // Fetch user by email from Firebase Core Data
    private func fetchUserByEmailFromCoreData(_ email: String) async -> Result<UserInfo?, Error> {
        let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let users = try await context.perform {
                try self.context.fetch(request)
            }
            
            return .success(users.first)
        } catch {
            return .failure(CoreDataError.fetchError)
        }
    }

    // Fetch user by email from Firebase Authentication
    private func fetchUserByEmailFromFirebase(_ email: String) async -> Result<UserInfo?, Error> {
        do {
            let firestore = Firestore.firestore()
            let query = firestore.collection("users").whereField("email", isEqualTo: email)
            let querySnapshot = try await query.getDocuments()
            
            if let document = querySnapshot.documents.first {
                _ = document.data()
                let userInfo = UserInfo() // Populate the UserInfo object with data from Firestore
                // Populate userInfo from userData as needed
                return .success(userInfo)
            } else {
                throw NSError(domain: "User not found in Firestore", code: 404, userInfo: nil)
            }
        } catch {
            return .failure(error)
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
        try await updateVerificationStatus(for: email, isVerified: true)
        
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

    private let userFetcher = UserFetcher()
    
    private func fetchUser(_ usernameOrEmail: String) async throws -> UserInfo? {
        if ValidationUtility.validateEmail(usernameOrEmail) != nil {
            // Fetch user by email or username using UserFetcher
            return try await userFetcher.fetchUser(usernameOrEmail: usernameOrEmail, context: nil as NSManagedObjectContext?)
        } else {
            // Fetch user by username using UserFetcher (pass nil for Firestore)
            return try await userFetcher.fetchUser(usernameOrEmail: usernameOrEmail, context: nil as NSManagedObjectContext?)
        }
    }
    
    // Fetch user by username from Firebase
    private func fetchUserByUsername(_ username: String) async throws -> UserInfo? {
        let firestore = Firestore.firestore()
        let query = firestore.collection("users").whereField("userName", isEqualTo: username)
        
        do {
            let querySnapshot = try await query.getDocuments()
            if let document = querySnapshot.documents.first {
                let userData = document.data()
                let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
                request.predicate = NSPredicate(format: "email == %@", userData["email"] as? String ?? "")
                
                let users = try await self.context.perform { // Explicitly reference 'self' here
                    try self.context.fetch(request) // And here as well
                }
                
                return users.first
            } else {
                throw NSError(domain: "User not found", code: 404, userInfo: nil)
            }
        } catch {
            throw error
        }
    }

    
    // Sign out user from Firebase
    func signOut() {
        do {
            try auth.signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func getUserId() async throws -> String {
        guard let user = auth.currentUser else {
            throw AuthError.notSignedIn
        }
        return user.uid
    }
    
    func updatePassword(_ newPassword: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotAuthenticated
        }

        // Update the password in Firebase Authentication
        try await user.updatePassword(to: newPassword)
        print("Password updated in Firebase.")
    }

    
}
