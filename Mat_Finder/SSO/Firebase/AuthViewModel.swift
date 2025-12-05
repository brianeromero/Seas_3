// AuthViewModel.swift
// Mat_Finder
//
// Created by Brian Romero on 10/22/24.

import Foundation
import SwiftUI // Add this line
import FirebaseCore
import FirebaseFirestore
import FirebaseAppCheck
@preconcurrency import FirebaseAuth
import CryptoSwift
@preconcurrency import CoreData
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
    case reauthenticationRequired
    case userNotFound



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
        case .reauthenticationRequired:
            return "You need to log in again before performing this action."
        case .unknownError:
            return "Unknown Error, please reach out to email: \(AppConstants.supportEmail)" // Using the constant from AppConstants
        case .userAlreadyExists:
            return "User Already Exists; please email: \(AppConstants.supportEmail) in order to be reset" // Using the constant from AppConstants
        case .invalidStoredPassword:
            return "Password stored is invalid"
        case .emptyPassword:
            return "Password cannot be empty."
        case .userNotFound:
            return "User not found. Please check your email or register a new account."
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


@MainActor
class AuthViewModel: ObservableObject {
    static var _shared: AuthViewModel?

    @MainActor
    static var shared: AuthViewModel {
        get {
            if _shared == nil {
                _shared = AuthViewModel(
                    managedObjectContext: PersistenceController.shared.container.viewContext,
                    emailManager: UnifiedEmailManager.shared,
                    authenticationState: AppDelegate.shared.authenticationState
                )
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
    private let logger = os.Logger(subsystem: "com.mat_Finder.app", category: "AuthViewModel")

    public var authenticationState: AuthenticationState

    var authStateHandle: AuthStateDidChangeListenerHandle?


    // Add a cancellables set to store Combine subscriptions
    private var cancellables = Set<AnyCancellable>() // Ensure this is present and initialized

    @MainActor
    public init(
        managedObjectContext: NSManagedObjectContext,
        emailManager: UnifiedEmailManager,
        authenticationState: AuthenticationState
    ) {
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
            Task {
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
 
    // MARK: - Create user (returns User)
    func createUser(
        withEmail email: String,
        password: String,
        userName: String,
        name: String,
        belt: String? = nil
    ) async throws -> User {
        
        // 1️⃣ Validate input
        guard !email.isEmpty, !password.isEmpty, !userName.isEmpty, !name.isEmpty else {
            throw AuthError.invalidInput
        }
        
        let normalizedEmail = email.lowercased()
        
        // 2️⃣ Check if user exists in Firestore
        if await userAlreadyExists(email: normalizedEmail, userName: userName) {
            throw AuthError.userAlreadyExists
        }
        
        do {
            // 3️⃣ Create Firebase Auth user
            let authResult = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
            let userID = authResult.user.uid
            
            // 4️⃣ Create User object for Firestore
            let newUser = User(
                email: normalizedEmail,
                userName: userName,
                name: name,
                passwordHash: Data(),
                salt: Data(),
                iterations: 0,
                isVerified: false,
                belt: belt ?? "",
                verificationToken: nil,
                userID: userID
            )
            
            // 5️⃣ Save to Firestore (await!)
            try Firestore.firestore()
                .collection("users")
                .document(userID)
                .setData(from: newUser)
            
            return newUser
            
        } catch {
            throw AuthError.firebaseError(error)
        }
    }

    
    // MARK: - Check if user already exists
    func userAlreadyExists(email: String, userName: String) async -> Bool {
        // 1️⃣ Check Core Data first
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ OR userName == %@", email, userName)

        do {
            let existingUsers = try context.fetch(fetchRequest)
            if !existingUsers.isEmpty {
                if existingUsers.first?.email == email {
                    self.errorMessage = "A user with this email address already exists."
                } else {
                    self.errorMessage = "A user with this username already exists."
                }
                self.showVerificationAlert = true
                return true
            }
        } catch {
            print("❌ Error checking user existence in Core Data: \(error.localizedDescription)")
            self.errorMessage = "Error checking user existence."
            return true
        }

        // 2️⃣ Check Firestore
        return await userAlreadyExistsInFirestore(email: email, userName: userName)
    }
    
    // MARK: - Firestore existence check
    func userAlreadyExistsInFirestore(email: String, userName: String) async -> Bool {
        let firestore = Firestore.firestore()

        let emailQuery = firestore.collection("users").whereField("email", isEqualTo: email)
        let userNameQuery = firestore.collection("users").whereField("userName", isEqualTo: userName)

        do {
            async let emailSnapshot = emailQuery.getDocuments()
            async let userNameSnapshot = userNameQuery.getDocuments()

            let (emailResult, userNameResult) = try await (emailSnapshot, userNameSnapshot)
            return !emailResult.documents.isEmpty || !userNameResult.documents.isEmpty
        } catch {
            print("❌ Error checking user existence in Firestore: \(error.localizedDescription)")
            self.errorMessage = "Error checking user existence."
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


    // Ensure fetchUserByEmail is async
    func fetchUserByEmail(_ email: String) async -> Result<UserInfo?, Error> {
        do {
            let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "email == %@", email)
            
            let users = try await context.perform {
                try self.context.fetch(fetchRequest)
            }
            
            return .success(users.first)
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
                return .success(users.first)
            } else {
                return .failure(NSError(domain: "User not found", code: 404))
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
    
    
    public func fetchUserName(forUserID userID: String) async -> String? {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID) // Assuming document ID is the userID

        do {
            let snapshot = try await userRef.getDocument()
            if let data = snapshot.data() {
                // Try to get 'userName' first
                if let userName = data["userName"] as? String {
                    self.logger.info("Fetched userName '\(userName, privacy: .public)' for userID: \(userID, privacy: .public)")
                    return userName
                }
                // If 'userName' is not found, fall back to 'name'
                else if let name = data["name"] as? String {
                    self.logger.warning("No 'userName' field found, falling back to 'name': '\(name, privacy: .public)' for userID: \(userID, privacy: .public)")
                    return name
                }
                // If neither 'userName' nor 'name' is found
                else {
                    self.logger.warning("Neither 'userName' nor 'name' field found for userID: \(userID, privacy: .public)")
                    return nil
                }
            } else {
                self.logger.warning("No document data found for userID: \(userID, privacy: .public)")
                return nil // No document data
            }
        } catch {
            self.logger.error("Error fetching user display name for userID \(userID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil // Error occurred during fetch
        }
    }

    
    public func fetchUserName(forUserName queriedUserName: String) async -> String? {
        let db = Firestore.firestore()
        let usersCollection = db.collection("users")

        self.logger.info("AuthViewModel: Querying for userName: \(queriedUserName, privacy: .public)") // Add this line

        do {
            let querySnapshot = try await usersCollection
                                        .whereField("userName", isEqualTo: queriedUserName)
                                        .getDocuments()

            if let document = querySnapshot.documents.first {
                let data = document.data()
                self.logger.info("AuthViewModel: Found document data: \(data, privacy: .public)") // Add this line
                if let userName = data["userName"] as? String {
                    self.logger.info("Fetched userName '\(userName, privacy: .public)' for query: \(queriedUserName, privacy: .public)")
                    return userName
                } else if let name = data["name"] as? String {
                    self.logger.warning("Document found for userName \(queriedUserName, privacy: .public), but no 'userName' field. Falling back to 'name': '\(name, privacy: .public)'.")
                    return name
                } else {
                    self.logger.warning("Document found for userName query \(queriedUserName, privacy: .public), but neither 'userName' nor 'name' field exists.")
                    return nil
                }
            } else {
                self.logger.warning("No user document found with userName matching: \(queriedUserName, privacy: .public)")
                return nil
            }
        } catch {
            self.logger.error("Error fetching user by userName \(queriedUserName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    
    // In AuthViewModel.swift
    public func fetchUserDisplayName(forUserID userID: String) async -> String? {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)

        do {
            let snapshot = try await userRef.getDocument()
            if let data = snapshot.data() {
                if let userName = data["userName"] as? String {
                    return userName
                } else if let name = data["name"] as? String {
                    return name
                }
            }
            return nil
        } catch {
            self.logger.error("Error fetching display name for user ID \(userID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
        let success = try! await emailManager.sendVerificationToken(to: email, userName: userName, password: password)
        if success {
            print("Custom verification email sent successfully.")
        } else {
            throw AuthError.firebaseError(NSError(domain: "Error sending custom verification email", code: -1, userInfo: nil))
        }
    }
    
    
///PART2
    // New method to add user to Core Data with password parameter
    // MARK: - Add user to Core Data
    private func addUserToCoreData(
        with userID: String,
        email: String,
        userName: String,
        name: String,
        belt: String?,
        password: String
    ) async throws {
        guard !password.isEmpty else {
            throw AuthError.emptyPassword
        }

        let hasher = HashPassword()
        let hashedPassword = try hasher.hashPasswordScrypt(password)

        let context = PersistenceController.shared.container.viewContext

        try await context.perform {
            let newUser = UserInfo(context: context)
            newUser.userID = userID
            newUser.email = email
            newUser.userName = userName
            newUser.name = name
            newUser.belt = belt ?? ""
            newUser.isVerified = false   // ✅ Default value for required field

            newUser.passwordHash = hashedPassword.hash
            newUser.salt = hashedPassword.salt
            newUser.iterations = Int64(hashedPassword.iterations)

            try context.save()
        }

        print("✅ Added user \(userName) to Core Data with hashed password.")
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
        print("User verification status before update: \(self.currentUser?.isVerified ?? false)")

        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "email == %@", email)

        do {
            let users = try await context.perform {
                try self.context.fetch(request)
            }
            if let user = users.first {
                user.isVerified = isVerified
                try context.save()
                print("User verification status updated for: \(user.email)")
                
                // ✅ Use userID for Firestore update
                guard let userID = user.userID else {
                    print("UserID is nil, cannot update Firestore")
                    return
                }

                let firestore = Firestore.firestore()
                let userRef = firestore.collection("users").document(userID)
                try await userRef.updateData(["isVerified": isVerified])

            } else {
                print("User not found in Core Data")
            }
        } catch {
            print("Failed to fetch or save user in Core Data: \(error)")
            throw CoreDataError.saveError
        }
    }


    func mapFirebaseUserToMat_FinderUser(firebaseUser: FirebaseAuth.User, userName: String, name: String) async throws -> User {
        let hashPassword = HashPassword()
        
        // Get entity description for UserInfo
        guard let entityDescription = NSEntityDescription.entity(forEntityName: "UserInfo", in: context) else {
            throw AuthError.firebaseError(NSError(domain: "Entity description not found", code: -1, userInfo: nil))
        }

        // Create UserInfo Core Data object
        let mat_FinderUser = UserInfo(entity: entityDescription, insertInto: context)
        mat_FinderUser.email = firebaseUser.email ?? ""
        mat_FinderUser.userName = userName
        mat_FinderUser.name = name
        mat_FinderUser.userID = firebaseUser.uid
        
        // Hash the password
        let hashedPassword = try hashPassword.hashPasswordScrypt(formState.password)
        mat_FinderUser.passwordHash = hashedPassword.hash
        mat_FinderUser.salt = hashedPassword.salt
        mat_FinderUser.iterations = Int64(hashedPassword.iterations)
        mat_FinderUser.isVerified = false
        
        // Save the Core Data context to persist the new UserInfo
        try context.save()
        
        // Convert the saved UserInfo to your User struct
        return User.fromUserInfo(mat_FinderUser)
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
    
    func fetchUserByFirebaseUID(firebaseUID: String) async -> UserInfo? {
        print("Fetching user with Firebase UID: \(firebaseUID)")
        
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "userID == %@", firebaseUID)
        
        do {
            let users = try await context.perform {
                try self.context.fetch(request)
            }
            return users.first
        } catch {
            print("Error fetching user by Firebase UID \(firebaseUID): \(error.localizedDescription)")
            return nil
        }
    }

    // Refactor sign-in method to separate password verification and Firebase authentication
    func signInUser(with identifier: String, password: String) async throws {
        // Fetch user metadata from Core Data
        guard let userInfo = try await fetchUser(identifier) else {
            throw AuthError.userNotFound
        }

        // Authenticate with Firebase
        let authResult = try await auth.signIn(withEmail: userInfo.email, password: password)

        // Update last login timestamp in Firestore
        let uid = authResult.user.uid
        try await updateFirestoreLoginTimestamp(for: uid)

        // Update UI state
        await MainActor.run {
            userSession = authResult.user
            currentUser = User.fromUserInfo(userInfo) // convert UserInfo -> User
        }
    }


    private func updateFirestoreLoginTimestamp(for userID: String) async throws {
        let userRef = Firestore.firestore().collection("users").document(userID)
        try await userRef.updateData(["lastLogin": Timestamp(date: Date())])
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

    func logAllUsers() async {
        let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        
        do {
            let users = try await context.perform {
                try self.context.fetch(request)
            }
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
        
        // Get userID from Core Data for consistency
        let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        let users = try await context.perform {
            try self.context.fetch(request)
        }

        guard let user = users.first else {
            throw AuthError.userNotFound
        }
        
        let firestore = Firestore.firestore()
        let userRef = firestore.collection("users").document(user.userID)
        
        try await userRef.setData(["isVerified": true], merge: true)
        print("Firestore verification status updated for UID: \(String(describing: user.userID))")
        return true
    }


    private let userFetcher = UserFetcher()
    
    private func fetchUser(_ usernameOrEmail: String) async throws -> UserInfo? {
        if ValidationUtility.validateEmail(usernameOrEmail) != nil {
            // Fetch user by email or username using UserFetcher
            // Note: Passing nil for context here might be an issue if UserFetcher needs it.
            // Ensure UserFetcher is correctly initialized or passed the context.
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

    /// SIGN IN WITH GOOGLE
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
    
    
    
    /// SIGN IN WITH APPLE

    func signInWithApple() {
        let coordinator = AppleSignInCoordinator()
        coordinator.startSignInWithAppleFlow { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let authResult):
                    guard let user = authResult.user.email else { return }
                    print("✅ Apple Sign-In success for \(user)")
                    
                    Task { // async call
                        await self?.handleUserLogin(firebaseUser: authResult.user)
                    }
                    
                case .failure(let error):
                    print("❌ Apple Sign-In failed: \(error.localizedDescription)")
                    self?.formState.alertMessage = error.localizedDescription
                    self?.formState.showAlert = true

                }
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

    
    @MainActor
    func handleUserLogin(firebaseUser: FirebaseAuth.User) async {
        let appUser = createUserObject(from: firebaseUser)
        let db = Firestore.firestore()
        
        do {
            try await db.collection("users").document(firebaseUser.uid).setData([
                "name": appUser.name,
                "userName": appUser.userName,
                "email": appUser.email,
                "isVerified": appUser.isVerified,
                "isBanned": false
            ], merge: true)
            
            logger.info("User uploaded to Firestore: \(appUser.name, privacy: .public)")
        } catch {
            logger.error("Failed to upload user to Firestore: \(error.localizedDescription, privacy: .public)")
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
    
    
    /// New method to perform a full logout and explicitly clear the navigation path.
    /// This should be called from your UI's logout button action.
    func logoutAndClearPath(path: Binding<NavigationPath>) async throws {
        do {
            // Perform the Firebase and Google sign-out logic
            // This is a call to another async function `signOut()`
            try await signOut()

            // Explicitly reset the navigation path on the main thread
            await MainActor.run {
                path.wrappedValue = NavigationPath()
                print("AuthViewModel: Explicitly cleared navigation path on logout.")
            }
        } catch {
            print("AuthViewModel: Error during logout: \(error.localizedDescription)")
            throw error // Re-throw the error so the UI can handle it
        }
    }
    

    @MainActor
    func deleteUser(recentPassword: String? = nil, googleIDToken: String? = nil, googleAccessToken: String? = nil) async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw AuthError.notSignedIn
        }
        
        let userID = firebaseUser.uid
        let email = firebaseUser.email ?? ""

        // Step 1: Reauthenticate
        do {
            if let password = recentPassword {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                try await firebaseUser.reauthenticate(with: credential)
            } else if let idToken = googleIDToken, let accessToken = googleAccessToken {
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                try await firebaseUser.reauthenticate(with: credential)
            } else {
                throw AuthError.reauthenticationRequired
            }
        } catch {
            logger.error("Reauthentication failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // Step 2: Delete Firestore document
        let userRef = Firestore.firestore().collection("users").document(userID)
        do {
            try await userRef.delete()
            logger.info("Deleted Firestore user document for UID: \(userID, privacy: .public)")
        } catch {
            logger.error("Error deleting Firestore user document: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // Step 3: Delete Firebase Auth user
        do {
            try await firebaseUser.delete()
            logger.info("Deleted Firebase Auth user: \(email, privacy: .public)")
        } catch {
            logger.error("Error deleting Firebase Auth user: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // Step 4: Delete Core Data UserInfo
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userID == %@", userID)
        
        do {
            if let userInfo = try context.fetch(fetchRequest).first {
                context.delete(userInfo)
                try context.save()
                logger.info("Deleted Core Data user: \(email, privacy: .public)")
            }
        } catch {
            logger.error("Error deleting Core Data user: \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // Step 5: Clear local state
        self.userSession = nil
        self.currentUser = nil
        self.usernameOrEmail = ""
        self.password = ""
        self.formState = FormState()
        self.userIsLoggedIn = false
    }

}

extension User {
    static func fromFirestoreData(_ data: [String: Any], uid: String) -> User {
        User(
            email: data["email"] as? String ?? "",
            userName: data["userName"] as? String ?? "",
            name: data["name"] as? String ?? "N/A", // Correctly extract 'name'
            passwordHash: Data(),           // leave empty if not stored on Firestore
            salt: Data(),                   // leave empty if not stored on Firestore
            iterations: 0,                  // default 0 or something meaningful
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
