//
//  AuthenticationState.swift
//  Seas_3
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
    @Published public var isAuthenticated: Bool = false
    @Published public var isLoggedIn = false
    @Published public var isAdmin = false               

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
        self.currentUser = nil
        updateAuthenticationStatus()
        Log.success("CoreData login successful: \(user.email)")
        
        loginCompletedSuccessfully()
    }
    
    // MARK: - Firestore Login
    /// Logs in with a Firestore `User` object
    public func login(user: User) {
        self.currentUser = user
        self.userInfo = nil
        updateAuthenticationStatus()
        print("✅ Logged in as Firestore user: \(user.userName)")
    }

    // MARK: - Logout
    /// Logs out the current user, resetting local state and signing out from Firebase
    public func logout(completion: @escaping () -> Void = {}) {
        Task {
            do {
                try await AuthViewModel.shared.logoutUser()
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
    /// Completes Google Sign-In flow and updates state accordingly
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
            
            print("🔑 Access Token: \(accessToken.prefix(20))...")
            print("🔑 ID Token: \(idToken.prefix(20))...")
            
            if let decoded = decodeJWTPart(idToken) {
                print("🧾 Decoded ID Token Payload: \(decoded)")
            }
            
            let email = user.profile?.email ?? "N/A"
            let name = user.profile?.name ?? "N/A"
            print("""
            🔍 Google Sign-In Result:
            - User ID: \(user.userID ?? "Missing User ID")
            - Name: \(name)
            - Email: \(email)
            """)
            
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
            
            try await createOrUpdateGoogleUserInFirestore(
                userID: firebaseUser.uid,
                email: email,
                userName: name,
                name: name,
                belt: nil
            )
            print("✅ Firestore user document created/updated for Google user")
            
            updateSocialUser(
                user.userID,
                name,
                email,
                profilePictureUrl: user.profile?.imageURL(withDimension: 200),
                provider: .google
            )
            
            loginCompletedSuccessfully()
            
        } catch {
            handleSignInError(error, message: "Google Sign-In failed: \(error.localizedDescription)")
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
    
    // MARK: - Social User Helper
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
        self.isAuthenticated = true
        self.isLoggedIn = true
        
        print("✅ Social user updated: \(name) (\(email)) via \(provider)")
    }
    
    func handleSuccessfulLogin(provider: SocialUser.Provider, user: FirebaseAuth.User?) async {
        guard let user = user else {
            handleSignInError(nil, message: "Firebase user is nil after sign-in.")
            return
        }
        
        updateSocialUser(
            user.uid,
            user.displayName ?? "Unknown",
            user.email ?? "No Email",
            profilePictureUrl: user.photoURL,
            provider: provider
        )
        
        loginCompletedSuccessfully()
    }
    
    // MARK: - Post-login actions
    @MainActor
    func loginCompletedSuccessfully() {
        self.isAuthenticated = true
        self.isLoggedIn = true
        self.navigateToAdminMenu = false
        
        print("🔑 AuthenticationState updated via loginCompletedSuccessfully:")
        print("    isAuthenticated = \(self.isAuthenticated)")
        print("    isLoggedIn = \(self.isLoggedIn)")
        print("    navigateToAdminMenu = \(self.navigateToAdminMenu)")
        
        Task {
            FirestoreSyncManager.shared.syncInitialFirestoreData()
        }
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
    
    // MARK: - Authentication Status Update
    private func updateAuthenticationStatus() {
        isAuthenticated = (userInfo != nil || currentUser != nil || socialUser != nil)
        isLoggedIn = isAuthenticated
        
        print("ℹ️ Auth Status -> isAuthenticated: \(isAuthenticated), isLoggedIn: \(isLoggedIn), isAdmin: \(isAdmin)")
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
    
    // MARK: - Admin Access
    public func adminLoginSucceeded() {
        isAuthenticated = true
        isLoggedIn = false
        isAdmin = true
        navigateToAdminMenu = true
        
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
