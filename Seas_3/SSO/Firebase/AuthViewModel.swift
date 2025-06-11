// AuthViewModel.swift
// Seas_3
//
// Created by Brian Romero on 10/22/24.

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAppCheck
@preconcurrency import FirebaseAuth
import CryptoSwift
import CoreData
import Combine
import os
import os.log
import GoogleSignIn


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
    case emptyPassword



    
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
        case .emptyPassword:
            return "Password cannot be empty."
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
    static var _shared: AuthViewModel?

    static var shared: AuthViewModel {
        get {
            if _shared == nil {
                _shared = AuthViewModel(authenticationState: AppDelegate.shared.authenticationState)
            }
            return _shared!
        }
    }


    @Published var usernameOrEmail: String = ""
    @Published var password: String = ""
    @Published var isSignInEnabled: Bool = false
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var showVerificationAlert: Bool = false
    @Published var isUserProfileActive: Bool = false
    @Published var formState: FormState = FormState()

    @Published var userIsLoggedIn: Bool = false // Initialize to false

    var currentUserID: String? {
        userSession?.uid ?? currentUser?.userID
    }

    private lazy var auth = Auth.auth()
    public let context: NSManagedObjectContext
    private let emailManager: UnifiedEmailManager
    private let logger = os.Logger(subsystem: "com.seas3.app", category: "AuthViewModel")


    public var authenticationState: AuthenticationState

    var authStateHandle: AuthStateDidChangeListenerHandle?

    // Add a cancellables set to store Combine subscriptions
    private var cancellables = Set<AnyCancellable>() // Ensure this is present and initialized

    public init(managedObjectContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
                emailManager: UnifiedEmailManager = .shared,
                authenticationState: AuthenticationState) {
        self.context = managedObjectContext
        self.emailManager = emailManager
        self.authenticationState = authenticationState

        $userSession
            .map { $0 != nil }
            .sink { [weak self] isLoggedIn in
                self?.userIsLoggedIn = isLoggedIn
            }
            .store(in: &cancellables)

        authStateHandle = auth.addStateDidChangeListener { [weak self] auth, user in
            // Ensure UI updates (including @Published properties) are on the main actor
            Task { @MainActor in // <--- Add @MainActor here
                await self?.updateCurrentUser(user: user)
                self?.userSession = user
            }
        }
    }


    // MARK: Create Firebase user with email/password
    @MainActor
    func updateCurrentUser(user: FirebaseAuth.User?) async {
        if let user = user {
            let currentUser = await getCurrentUser()
            if let currentUser = currentUser {
                self.currentUser = currentUser
            }
            self.userSession = user
        } else {
            self.currentUser = nil
            self.userSession = nil
        }
    }
    
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
                try addUserToCoreData(with: userId, email: email, userName: userName, name: name, belt: belt, password: password)
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

        // Query 1: Check email
        let emailQuery = firestore.collection("users").whereField("email", isEqualTo: formState.email)
        // Query 2: Check username
        let userNameQuery = firestore.collection("users").whereField("userName", isEqualTo: formState.userName)
        
        do {
            async let emailSnapshot = emailQuery.getDocuments()
            async let userNameSnapshot = userNameQuery.getDocuments()
            
            let (emailResult, userNameResult) = try await (emailSnapshot, userNameSnapshot)
            
            return !emailResult.documents.isEmpty || !userNameResult.documents.isEmpty
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

/*    // Add this method to AuthViewModel
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
 */

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

    private func createFirestoreDocument(
        for userID: String,
        email: String,
        userName: String,
        name: String,
        belt: String? = ""
    ) async throws {
        let userData: [String: Any] = [
            "email": email,
            "userName": userName,
            "name": name,
            "userID": userID,
            "belt": belt ?? "", // ensure belt always has a value
            "isVerified": false,
            "createdAt": Timestamp(),
            "lastLogin": Timestamp()
        ]
        
        let userRef = Firestore.firestore().collection("users").document(userID)
        try await userRef.setData(userData, merge: true)
    }

    private func sendVerificationEmail(to email: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.invalidInput
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.sendEmailVerification { error in
                if let error = error {
                    continuation.resume(throwing: AuthError.firebaseError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func sendCustomVerificationEmail(to email: String, userName: String, password: String) async throws {
        let success = await emailManager.sendVerificationToken(to: email, userName: userName, password: password)
        if success {
            print("Custom verification email sent successfully.")
        } else {
            throw AuthError.firebaseError(NSError(domain: "Error sending custom verification email", code: -1, userInfo: nil))
        }
    }
    
///PART2
    // New method to add user to Core Data with password parameter
    private func addUserToCoreData(
        with userID: String,
        email: String,
        userName: String,
        name: String,
        belt: String?,
        password: String
    ) throws {
        // Check that password is not empty
        guard !password.isEmpty else {
            throw AuthError.emptyPassword // You can define this error type accordingly
        }
        
        let hashPassword = HashPassword()
        let newUser = UserInfo(context: context)
        newUser.userID = userID
        newUser.userName = userName
        newUser.email = email
        newUser.name = name
        newUser.isVerified = false
        
        // Assign belt or clear it explicitly
        newUser.belt = belt ?? ""
        
        // Hash the password using Scrypt
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

    func mapFirebaseUserToSeasUser(firebaseUser: FirebaseAuth.User, userName: String, name: String) async throws -> User {
        let hashPassword = HashPassword()
        
        // Get entity description for UserInfo
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "UserInfo", in: context) else {
            throw AuthError.firebaseError(NSError(domain: "Entity description not found", code: -1, userInfo: nil))
        }

        // Create UserInfo Core Data object
        let seasUser = UserInfo(entity: entityDescription, insertInto: context)
        seasUser.email = firebaseUser.email ?? ""
        seasUser.userName = userName
        seasUser.name = name
        seasUser.userID = firebaseUser.uid
        
        // Hash the password
        let hashedPassword = try hashPassword.hashPasswordScrypt(formState.password)
        seasUser.passwordHash = hashedPassword.hash
        seasUser.salt = hashedPassword.salt
        seasUser.iterations = Int64(hashedPassword.iterations)
        seasUser.isVerified = false
        
        // Save the Core Data context to persist the new UserInfo
        try context.save()
        
        // Convert the saved UserInfo to your User struct
        return User.fromUserInfo(seasUser)
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
        let hashPassword = HashPassword()
        print("Signing in user \(identifier)...")
        
        // Fetch user from Core Data
        guard let user = try await fetchUser(identifier) else {
            print("User not found for identifier: \(identifier)")
            throw NSError(domain: ErrorDomain.auth.rawValue, code: ErrorCode.userNotFound.rawValue, userInfo: nil)
        }
        
        // Use raw Data directly (no Base64 decode)
        let storedSalt = user.salt
        let storedHash = user.passwordHash

        guard !storedSalt.isEmpty, !storedHash.isEmpty else {
            throw AuthError.invalidStoredPassword
        }

        // Debug the stored salt value
        print("Stored Salt length: \(storedSalt.count)")
        
        let storedHashedPassword = HashedPassword(hash: storedHash, salt: storedSalt, iterations: Int(user.iterations))

        // Verify password using SCRYPT
        guard try hashPassword.verifyPasswordScrypt(password, againstHash: storedHashedPassword) else {
            throw AuthError.passwordsDoNotMatch
        }

        // Proceed with Firebase authentication
        let authResult = try await auth.signIn(withEmail: user.email, password: password)
        
        // Update Firestore last login timestamp
        try await updateFirestoreLoginTimestamp(for: user.email)
        
        // Map Firebase user to local user model
        let currentUser = try await mapFirebaseUserToSeasUser(firebaseUser: authResult.user, userName: user.userName, name: user.name)

        // Update UI state on main thread
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
    // Updated to return User struct instead of UserInfo?
    private func fetchUserByEmailFromFirebase(_ email: String) async -> Result<User, Error> {
        do {
            let firestore = Firestore.firestore()
            let query = firestore.collection("users").whereField("email", isEqualTo: email)
            let snapshot = try await query.getDocuments()
            
            guard let document = snapshot.documents.first else {
                return .failure(NSError(domain: "User not found", code: 404, userInfo: nil))
            }
            
            let user = User.fromFirestoreData(document.data(), uid: document.documentID)
            return .success(user)
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
            guard let document = querySnapshot.documents.first else {
                throw NSError(domain: "User not found", code: 404, userInfo: nil)
            }
            
            let data = document.data()
            _ = User.fromFirestoreData(data, uid: document.documentID)
            
            // Fetch UserInfo from Core Data matching the email from Firestore
            let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
            if let email = data["email"] as? String {
                request.predicate = NSPredicate(format: "email == %@", email)
            } else {
                // If email missing in data, return nil or throw error
                return nil
            }
            
            // Perform Core Data fetch on the context's queue
            let users = try await context.perform {
                try self.context.fetch(request)
            }
            
            return users.first
        } catch {
            throw error
        }
    }

    // Add this new method for Google Sign-In
    @MainActor
    func signInWithGoogle(presenting viewController: UIViewController) async {
        logger.debug("AuthViewModel: Google sign-in started.")
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
            logger.debug("AuthViewModel: Google sign-in succeeded. User: \(result.user.profile?.email ?? "unknown email", privacy: .public)")

            // Call the completeGoogleSignIn method in AuthenticationState
            // This is the crucial link to update the main app state
            await authenticationState.completeGoogleSignIn(with: result)

            // Optionally, handle user data or create/update user in Firestore/CoreData here
            // based on the Google sign-in result, similar to how you do it for email/password.
            // Example:
            // if let firebaseAuthCredential = GoogleAuthProvider.credential(withIDToken: result.idToken.tokenString, accessToken: result.accessToken.tokenString) {
            //      let firebaseResult = try await auth.signIn(with: firebaseAuthCredential)
            //      handleUserLogin(firebaseUser: firebaseResult.user)
            // }

        } catch {
            logger.error("AuthViewModel: Google sign-in error: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.showVerificationAlert = true // Or another state for showing error
            }
        }
    }
    
    
    // Sign out user from Firebase with a completion handler
    // Modify signOut to be throwing for consistency with how it's called
    func signOut() async throws { // Make it throwing
        do {
            try auth.signOut()
            print("Firebase sign-out successful.")

            // Ensure Google sign-out is always attempted if GIDSignIn is initialized
            GIDSignIn.sharedInstance.signOut()
            print("Google sign-out successful.")

            // Reset states on the main actor
            await MainActor.run {
                self.userSession = nil
                self.currentUser = nil
                self.usernameOrEmail = ""
                self.password = ""
                self.isSignInEnabled = false
                self.formState = FormState()
            }
            print("AuthViewModel states cleared locally.")
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            throw error // Re-throw the error so AuthenticationState can catch it
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
    
    // Convert FirebaseAuth.User to your custom UserInfo type
    func convertToAppUser(from firebaseUser: FirebaseAuth.User) -> UserInfo {
        let userInfo = UserInfo(context: context)
        userInfo.userID = firebaseUser.uid
        userInfo.name = firebaseUser.displayName ?? "Anonymous"
        userInfo.userName = firebaseUser.displayName ?? "anonymous_user"
        print("Object type: \(type(of: userInfo))")

        userInfo.email = firebaseUser.email ?? "no-email@unknown.com"
        userInfo.passwordHash = Data()
        userInfo.salt = Data()
        userInfo.isVerified = false
        userInfo.isBanned = false

        // Do NOT save to Core Data if you don't persist users
        return userInfo
    }
    
    func createUserObject(from firebaseUser: FirebaseAuth.User) -> User {
        return User(
            email: firebaseUser.email ?? "",
            userName: firebaseUser.displayName ?? "anonymous_user",
            name: firebaseUser.displayName ?? "Anonymous",
            passwordHash: Data(), // unused for Firebase auth
            salt: Data(),
            iterations: 0,
            isVerified: false,
            belt: "", // default to "Not selected"
            verificationToken: nil,
            userID: firebaseUser.uid
        )
    }

    
    func handleUserLogin(firebaseUser: FirebaseAuth.User) {
        let appUser = createUserObject(from: firebaseUser)

        let db = Firestore.firestore()
        db.collection("users").document(firebaseUser.uid).setData([
            "name": appUser.name,
            "userName": appUser.userName,
            "email": appUser.email,
            "isVerified": appUser.isVerified,
            "isBanned": false
        ], merge: true) { error in
            if let error = error {
                // Change from os_log to logger.error
                self.logger.error("Failed to upload user to Firestore: \(error.localizedDescription, privacy: .public)")
            } else {
                // Change from os_log to logger.info
                self.logger.info("User uploaded to Firestore: \(appUser.name, privacy: .public)")
            }
        }
    }

    func getCurrentUser() async -> User? {
        guard let firebaseUser = Auth.auth().currentUser else {
            // Change from os_log to logger.error
            logger.error("No Firebase Auth user currently signed in")
            return nil
        }

        let db = Firestore.firestore()
        let documentRef = db.collection("users").document(firebaseUser.uid)

        do {
            let snapshot = try await documentRef.getDocument()
            
            guard let data = snapshot.data() else {
                // Change from os_log to logger.error
                logger.error("No Firestore data found for UID: \(firebaseUser.uid, privacy: .public)")
                return nil
            }

            let user = User.fromFirestoreData(data, uid: firebaseUser.uid)

            // Change from os_log to logger.info
            logger.info("Fetched Firestore user info: Email=\(user.email, privacy: .public), Name=\(user.name, privacy: .public), Belt=\(user.belt ?? "nil", privacy: .public), Verified=\(user.isVerified, privacy: .public)")

            await MainActor.run {
                self.currentUser = user
            }

            return user

        } catch {
            // Change from os_log to logger.error
            logger.error("Firestore fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

extension User {
    static func fromFirestoreData(_ data: [String: Any], uid: String) -> User {
        User(
            email: data["email"] as? String ?? "",
            userName: data["userName"] as? String ?? "",
            name: data["name"] as? String ?? "",
            passwordHash: Data(),          // leave empty if not stored on Firestore
            salt: Data(),                  // leave empty if not stored on Firestore
            iterations: 0,                 // default 0 or something meaningful
            isVerified: data["isVerified"] as? Bool ?? false,
            belt: data["belt"] as? String,
            verificationToken: nil,
            userID: uid
        )
    }
}

extension User {
    static func fromUserInfo(_ userInfo: UserInfo) -> User {
        User(
            email: userInfo.email,
            userName: userInfo.userName,
            name: userInfo.name,
            passwordHash: userInfo.passwordHash,
            salt: userInfo.salt,
            iterations: Int64(Int(userInfo.iterations)),
            isVerified: userInfo.isVerified,
            belt: userInfo.belt,
            verificationToken: nil,
            userID: userInfo.userID
        )
    }
}
