//
//  AuthenticationState.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/5/24.
//

import Foundation
import SwiftUI
import Combine
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FBSDKLoginKit
import GoogleSignIn
import OSLog



enum Log {
    static func success(_ message: String) {
        print("✅ \(message)")
    }

    static func failure(_ message: String) {
        print("❌ \(message)")
    }

    static func info(_ message: String) {
        print("ℹ️ \(message)")
    }
}


// MARK: - Validator Protocol
public protocol Validator {
    func isValidEmail(_ email: String) -> Bool
}

// MARK: - SocialUser Struct
public struct SocialUser {
    public enum Provider {
        case google
        case facebook
    }

    public var provider: Provider
    public var id: String
    public var name: String
    public var email: String
    public var profilePictureUrl: URL?

    public init(provider: Provider, id: String, name: String, email: String, profilePictureUrl: URL? = nil) {
        self.provider = provider
        self.id = id
        self.name = name
        self.email = email
        self.profilePictureUrl = profilePictureUrl
    }
}

// MARK: - EmailValidator
public class EmailValidator: Validator {
    public init() {}

    public func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - AuthenticationState

@MainActor
public class AuthenticationState: ObservableObject {
    // MARK: - Published Properties
    @Published public var isAuthenticated: Bool = false {
        didSet {
            // Add your print here to see every change
            print("➡️ AuthenticationState.isAuthenticated changed to: \(isAuthenticated)")
        }
    }
    @Published public var isLoggedIn = false { // Keep this separate if it has distinct meaning
        didSet {
            // Add your print here to see every change
            print("➡️ AuthenticationState.isLoggedIn changed to: \(isLoggedIn)")
            if isLoggedIn { // This is where you might log "User logged in" once
                 os_log("User logged in", log: OSLog(subsystem: "com.yourapp.auth", category: "login"))
            }
        }
    }
    @Published public var isAdmin = false {
        didSet {
            print("➡️ AuthenticationState.isAdmin changed to: \(isAdmin)")
        }
    }
    @Published public private(set) var socialUser: SocialUser?
    @Published public private(set) var userInfo: UserInfo?
    @Published public private(set) var currentUser: User?

    @Published public private(set) var errorMessage = ""
    @Published public private(set) var hasError = false

    @Published public var navigateToAdminMenu = false


    // MARK: - Private Properties
    private let validator: Validator
    private let hashPassword: PasswordHasher

    // MARK: - Initializer
    public init(hashPassword: PasswordHasher, validator: Validator = EmailValidator()) {
        self.hashPassword = hashPassword
        self.validator = validator
        print("🔧 AuthenticationState initialized with \(type(of: validator)) validator.")
    }
    
    // MARK: - CoreData Login
    /// Attempts login with a local CoreData user and plaintext password
    public func login(_ user: UserInfo, password: String) throws {
        print("🔐 Attempting CoreData login for user: \(user.email)")

        guard validator.isValidEmail(user.email) else {
            print("❌ Invalid email format: \(user.email)")
            throw AuthenticationError.invalidEmail
        }

        guard !user.passwordHash.isEmpty else {
            print("❌ Password hash is empty for user: \(user.email)")
            throw AuthenticationError.invalidCredentials
        }

        do {
            let hashedPassword = try convertToHashedPassword(user.passwordHash)
            guard try hashPassword.verifyPasswordScrypt(password, againstHash: hashedPassword) else {
                print("❌ Password verification failed for user: \(user.email)")
                throw AuthenticationError.invalidPassword
            }
        } catch {
            print("❌ Error during password verification: \(error.localizedDescription)")
            throw AuthenticationError.serverError
        }

        guard user.isVerified else {
            print("⚠️ User email is not verified: \(user.email)")
            throw AuthenticationError.unverifiedEmail
        }

        self.userInfo = user
        self.currentUser = nil // Keep this, as it differentiates CoreData from Firestore user
        // updateAuthenticationStatus() // <<-- REMOVE THIS CALL HERE
        Log.success("CoreData login successful: \(user.email)")

        // THIS IS NOW THE SOLE POINT of setting isLoggedIn/isAuthenticated to true
        loginCompletedSuccessfully()
    }
    
    // MARK: - Firestore Login
    /// Logs in with a Firestore `User` object
    public func login(user: User) {
        self.currentUser = user
        self.userInfo = nil // Keep this
        // updateAuthenticationStatus() // <<-- REMOVE THIS CALL HERE
        print("✅ Logged in as Firestore user: \(user.userName)")
        // Ensure this also calls the unified completion
        loginCompletedSuccessfully() // <<-- ADD THIS CALL HERE
    }

    // MARK: - Logout
    /// Logs out the current user, resetting local state and signing out from Firebase
    public func logout(completion: @escaping () -> Void = {}) {
        Task {
            do {
                // IMPORTANT CHANGE: Call the comprehensive signOut method
                try await AuthViewModel.shared.signOut() // Make signOut throwing
                reset()
                print("🔒 Logout complete.")
                completion()
            } catch {
                print("❌ Logout failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                hasError = true
                completion()
            }
        }
    }


    // MARK: - Google Sign-In Completion
    public func completeGoogleSignIn(with result: GIDSignInResult) async {
        print("➡️ Starting completeGoogleSignIn...")

        let user = result.user

        do {
            let authentication = try await user.refreshTokensIfNeeded()
            let accessToken = authentication.accessToken.tokenString
            guard let idToken = authentication.idToken?.tokenString else {
                handleSignInError(nil, message: "Google Sign-In failed: No ID token.")
                return
            }

            // ... (Your existing logging for tokens)

            if Auth.auth().currentUser == nil {
                try await signInToFirebase(idToken: idToken, accessToken: accessToken)
                print("✅ Signed in to Firebase with Google credentials.")
            } else {
                try await linkOrSignInWithGoogleCredential(idToken: idToken, accessToken: accessToken)
            }

            guard let firebaseUser = Auth.auth().currentUser else {
                handleSignInError(nil, message: "Firebase user not available after sign-in.")
                return
            }

            try await createGoogleUserIfNeeded(
                userID: firebaseUser.uid,
                email: firebaseUser.email ?? user.profile?.email ?? "N/A",
                userName: firebaseUser.displayName ?? user.profile?.name ?? "N/A",
                name: firebaseUser.displayName ?? user.profile?.name ?? "N/A"
            )

            print("✅ Firestore user document created/updated for Google user")

            // updateSocialUser should now set socialUser, but NOT isAuthenticated/isLoggedIn
            updateSocialUser(
                user.userID, // This is the Google user ID, not Firebase UID
                user.profile?.name ?? "N/A",
                user.profile?.email ?? "N/A",
                profilePictureUrl: user.profile?.imageURL(withDimension: 200),
                provider: .google
            )

            // THIS IS NOW THE SOLE POINT of setting isLoggedIn/isAuthenticated to true
            loginCompletedSuccessfully()

        } catch {
            handleSignInError(error, message: "Google Sign-In failed: \(error.localizedDescription)")
        }
    }
    
    private func createGoogleUserIfNeeded(
        userID: String,
        email: String,
        userName: String,
        name: String
    ) async throws {
        let userRef = Firestore.firestore().collection("users").document(userID)
        let docSnapshot = try await userRef.getDocument()

        if !docSnapshot.exists {
            let userData: [String: Any] = [
                "email": email,
                "userName": userName,
                "name": name,
                "userID": userID,
                "belt": "",             // leave empty on first login
                "isVerified": true,
                "createdAt": Timestamp(),
                "lastLogin": Timestamp()
            ]
            try await userRef.setData(userData, merge: false)
            print("✅ Created new Google user in Firestore")
        } else {
            // Only update lastLogin (don’t touch profile fields)
            try await userRef.setData(["lastLogin": Timestamp()], merge: true)
            print("🔄 Updated lastLogin for Google user in Firestore")
        }
    }

    
    private func linkOrSignInWithGoogleCredential(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        guard let currentUser = Auth.auth().currentUser else {
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Signed in with Google credential: \(authResult.user.uid)")
            await handleSuccessfulLogin(provider: .google, user: authResult.user)
            return
        }
        
        do {
            let authResult = try await currentUser.link(with: credential)
            print("✅ Linked Google account to existing user: \(authResult.user.uid)")
            await handleSuccessfulLogin(provider: .google, user: authResult.user)
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            print("⚠️ Credential already in use. Attempting direct sign-in.")
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Signed in with Google credential: \(authResult.user.uid)")
            await handleSuccessfulLogin(provider: .google, user: authResult.user)
        }
    }
    
    private func createOrUpdateGoogleUserInFirestore(
        userID: String,
        email: String,
        userName: String,
        name: String,
        belt: String? = ""
    ) async throws {
        guard !userID.isEmpty else {
            throw NSError(domain: "UserIDMissing", code: 0, userInfo: [NSLocalizedDescriptionKey: "UserID is empty"])
        }
        
        let userRef = Firestore.firestore().collection("users").document(userID)
        let docSnapshot = try await userRef.getDocument()
        
        var userData: [String: Any] = [
            "email": email,
            "userName": userName,
            "name": name,
            "userID": userID,
            "belt": belt ?? "",
            "isVerified": true,
            "lastLogin": Timestamp()
        ]
        
        if !docSnapshot.exists {
            userData["createdAt"] = Timestamp()
        }
        
        try await userRef.setData(userData, merge: true)
    }
    
    // MARK: - Facebook Sign-In
    /// Signs in with Facebook credentials via Firebase Auth
    public func signInWithFacebook() async {
        do {
            guard let accessToken = AccessToken.current else {
                throw NSError(domain: "AuthenticationState", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Facebook login failed. Try again."
                ])
            }
            
            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
            try await signInToFirebase(with: credential)
        } catch {
            handleSignInError(error)
        }
    }
    
    // MARK: - Firebase Sign-In Helpers
    internal func signInToFirebase(with credential: AuthCredential) async throws {
        let result = try await Auth.auth().signIn(with: credential)
        print("🔍 Current Firebase user: \(Auth.auth().currentUser?.uid ?? "nil")")
        await handleSuccessfulLogin(provider: detectProvider(from: credential), user: result.user)
    }
    
    func signInToFirebase(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        if let currentUser = Auth.auth().currentUser {
            do {
                let authResult = try await currentUser.link(with: credential)
                print("✅ Linked Google account to existing user: \(authResult.user.uid)")
                await handleSuccessfulLogin(provider: .google, user: authResult.user)
            } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                print("⚠️ Credential already in use. Attempting direct sign-in.")
                let authResult = try await Auth.auth().signIn(with: credential)
                print("✅ Signed in with Google credential: \(authResult.user.uid)")
                await handleSuccessfulLogin(provider: .google, user: authResult.user)
            }
        } else {
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Signed in with Google credential: \(authResult.user.uid)")
            await handleSuccessfulLogin(provider: .google, user: authResult.user)
        }
    }
    
    private func detectProvider(from credential: AuthCredential) -> SocialUser.Provider {
        switch credential.provider {
        case "google.com": return .google
        case "facebook.com": return .facebook
        default:
            print("⚠️ Unknown provider: \(credential.provider). Defaulting to Google.")
            return .google
        }
    }
    
    // MARK: - Social User Helper (Modified)
    public func updateSocialUser(
        _ userID: String?,
        _ name: String,
        _ email: String,
        profilePictureUrl: URL?,
        provider: SocialUser.Provider
    ) {
        guard let userID = userID, !name.isEmpty, !email.isEmpty else {
            handleSignInError(nil, message: "Missing social login user info.")
            return
        }

        let socialUser = SocialUser(
            provider: provider,
            id: userID,
            name: name,
            email: email,
            profilePictureUrl: profilePictureUrl
        )

        self.socialUser = socialUser
        // self.isAuthenticated = true // <<-- REMOVE THIS LINE
        // self.isLoggedIn = true      // <<-- REMOVE THIS LINE

        print("✅ Social user updated: \(name) (\(email)) via \(provider)")
    }
    
    // MARK: - Handle Successful Login (Modified)
    func handleSuccessfulLogin(provider: SocialUser.Provider, user firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser = firebaseUser else {
            handleSignInError(nil, message: "Firebase user is nil after sign-in.")
            return
        }

        // Attempt to load the full user profile from Firestore if it exists.
        // This is the most robust way to ensure your custom `User` model is fully populated.
        let userDocRef = Firestore.firestore().collection("users").document(firebaseUser.uid)
        do {
            let docSnapshot = try await userDocRef.getDocument()
            if docSnapshot.exists, let userFromFirestore = User(fromFirestoreDocument: docSnapshot) {
                self.currentUser = userFromFirestore
                print("✅ Successfully loaded custom User from Firestore for UID: \(firebaseUser.uid)")
            } else {
                // If document doesn't exist or decoding failed, create a basic User from FirebaseAuth.User
                self.currentUser = User(firebaseUser: firebaseUser)
                print("⚠️ Firestore user document not found or could not be decoded. Created basic User from FirebaseAuth.User for UID: \(firebaseUser.uid)")
            }
        } catch {
            print("❌ Error fetching/decoding Firestore user document for UID: \(firebaseUser.uid). Fallback to basic User. Error: \(error.localizedDescription)")
            self.currentUser = User(firebaseUser: firebaseUser) // Fallback in case of error
        }

        self.userInfo = nil // Ensure other user types are nil

        updateSocialUser(
            firebaseUser.uid, // Use Firebase UID for socialUser ID
            firebaseUser.displayName ?? "Unknown",
            firebaseUser.email ?? "No Email",
            profilePictureUrl: firebaseUser.photoURL,
            provider: provider
        )

        loginCompletedSuccessfully()
    }
    
    // MARK: - Post-login actions
    @MainActor
    func loginCompletedSuccessfully() {
        isAuthenticated = (userInfo != nil || currentUser != nil || socialUser != nil)
        isLoggedIn = isAuthenticated
        isAdmin = determineIfAdmin()
        navigateToAdminMenu = isAdmin

        print("🔑 AuthenticationState updated via loginCompletedSuccessfully:")
        print("    isAuthenticated = \(self.isAuthenticated)")
        print("    isLoggedIn = \(self.isLoggedIn)")
        print("    isAdmin = \(self.isAdmin)")
        print("    navigateToAdminMenu = \(self.navigateToAdminMenu)")

        // Start listening for the user's document in Firestore after successful login
        FirestoreManager.shared.startListeningForUserDocument()
        // If you have other initial data you want to sync with listeners on login, call them here too:
        // FirestoreManager.shared.startListeningForCollection(collection: .appDayOfWeeks) { documents in /* handle */ }

    }
    
    // Implement this function to determine if the user is an admin
    private func determineIfAdmin() -> Bool {
        // Example: Check if currentUser has a specific role
        // if let firebaseUser = currentUser, firebaseUser.customClaims?["admin"] as? Bool == true {
        //     return true
        // }
        // Example: Check if userInfo (CoreData) has an admin flag
        // if let coreDataUser = userInfo, coreDataUser.isAdminAccount {
        //     return true
        // }
        return false // Default until implemented
    }
    
    
    // MARK: - Error Handling
    func handleSignInError(_ error: Error?, message: String? = nil) {
        hasError = true
        errorMessage = message ?? error?.localizedDescription ?? "Unknown error."
        
        print("🚨 Sign-In Error: \(errorMessage)")
        
        if let nsError = error as NSError? {
            print("📦 NSError - Domain: \(nsError.domain), Code: \(nsError.code)")
            print("🔍 UserInfo: \(nsError.userInfo)")
        }
    }
    
    // MARK: - Authentication Status Update (Modified)
    private func updateAuthenticationStatus() {
        // This function is no longer setting the core login state.
        // Its purpose is to derive the state from `userInfo`, `currentUser`, `socialUser`.
        // It's still useful for sanity checks, but don't call it if you're
        // about to call loginCompletedSuccessfully().
        isAuthenticated = (userInfo != nil || currentUser != nil || socialUser != nil)
        isLoggedIn = isAuthenticated // Let isLoggedIn derive from isAuthenticated
        print("ℹ️ Auth Status (internal): isAuthenticated: \(isAuthenticated), isLoggedIn: \(isLoggedIn), isAdmin: \(isAdmin)")
    }
    
    // MARK: - Password Handling
    private func convertToHashedPassword(_ passwordHash: Data) throws -> HashedPassword {
        let separatorData = Data(hashPassword.base64SaltSeparator.utf8)
        
        guard let separatorIndex = passwordHash.range(of: separatorData)?.lowerBound else {
            print("❌ Failed to find salt separator in password hash.")
            print("🔎 Separator expected: \(hashPassword.base64SaltSeparator)")
            print("🧵 PasswordHash (base64): \(passwordHash.base64EncodedString())")
            throw HashError.invalidInput
        }
        
        let salt = passwordHash[..<separatorIndex]
        let hash = passwordHash[separatorIndex...].dropFirst(separatorData.count)
        
        guard !salt.isEmpty && !hash.isEmpty else {
            print("⚠️ Warning: Extracted salt or hash is empty.")
            throw HashError.invalidInput
        }
        
        return HashedPassword(hash: hash, salt: salt, iterations: 8)
    }
    
    // MARK: - JWT Decoding Helper
    func decodeJWTPart(_ value: String) -> String? {
        let segments = value.split(separator: ".")
        guard segments.count > 1 else { return nil }
        
        var base64String = String(segments[1])
        base64String = base64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64String.count % 4 != 0 {
            base64String.append("=")
        }
        
        guard let data = Data(base64Encoded: base64String),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return decoded
    }
    
    // MARK: - Admin Access (Review this method)
    public func adminLoginSucceeded() {
        // This method bypasses the normal login flow. Ensure it correctly sets
        // all necessary state.
        isAuthenticated = true
        isLoggedIn = false // Admin is not "logged in" as a regular user, or is it? Clarify this logic.
        isAdmin = true
        navigateToAdminMenu = true

        // Ensure this triggers a UI update correctly
        print("🛡️ Admin login succeeded. isAdmin: \(isAdmin), navigateToAdminMenu: \(navigateToAdminMenu)")
    }
    
    // MARK: - Public Setters (MainActor safe)

    @MainActor
    public func setIsAuthenticated(_ value: Bool) {
        isAuthenticated = value
    }

    @MainActor
    public func setIsLoggedIn(_ value: Bool) {
        isLoggedIn = value
    }

    @MainActor
    public func setIsAdmin(_ value: Bool) {
        isAdmin = value
    }

    @MainActor
    public func setErrorMessage(_ message: String) {
        errorMessage = message
        hasError = !message.isEmpty
    }

    @MainActor
    public func reset() {
        setIsAuthenticated(false)
        setIsLoggedIn(false)
        setIsAdmin(false)
        navigateToAdminMenu = false
        socialUser = nil
        userInfo = nil
        currentUser = nil
        errorMessage = ""
        hasError = false

        // IMPORTANT: Call cleanup methods on any managers that hold state or listeners
        // CORRECTED LINE:
        FirestoreManager.shared.stopAllListeners() // <--- Change this line

        // If you have a LocationManager singleton:
        // LocationManager.shared.stopUpdatingLocation() // Implement this in your LocationManager
        // LocationManager.shared.resetState() // If LocationManager holds internal state

        print("🔄 AuthenticationState has been fully reset.")
    }
    
    // MARK: - Errors
    public enum AuthenticationError: LocalizedError {
        case invalidEmail
        case invalidCredentials
        case invalidPassword
        case unverifiedEmail
        case serverError
        
        public var errorDescription: String? {
            switch self {
            case .invalidEmail: return "Invalid email address."
            case .invalidCredentials: return "Invalid login credentials."
            case .invalidPassword: return "Incorrect password."
            case .unverifiedEmail: return "Email is not verified."
            case .serverError: return "An internal error occurred."
            }
        }
    }
    
    
}

// MARK: - SocialUser.Provider Description

extension SocialUser.Provider: CustomStringConvertible {
    public var description: String {
        switch self {
        case .google: return "Google"
        case .facebook: return "Facebook"
        @unknown default: return "Unknown Provider"
        }
    }
}
