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
    @Published var isAuthenticated: Bool = false
    @Published var isLoggedIn: Bool = false

    @Published var isAdmin: Bool = false
    @Published var socialUser: SocialUser?
    @Published var userInfo: UserInfo?
    @Published var currentUser: User?
    @Published var errorMessage: String = ""
    @Published var hasError: Bool = false
    @Published var navigateToAdminMenu: Bool = false
    
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
            if try !hashPassword.verifyPasswordScrypt(password, againstHash: hashedPassword) {
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
    }
    
    // MARK: - Firestore Login
    public func login(user: User) {
        self.currentUser = user
        self.userInfo = nil
        updateAuthenticationStatus()
        print("✅ Logged in as Firestore user: \(user.userName)")
    }

    // MARK: - Logout
    public func logout(completion: @escaping () -> Void = {}) {
        print("🔒 Logging out...")
        resetState()
        completion()
        print("🔒 Logout complete.")
    }

    private func resetState() {
        self.userInfo = nil
        self.currentUser = nil
        self.socialUser = nil
        self.isAuthenticated = false
        self.isLoggedIn = false
        self.isAdmin = false
        self.hasError = false
        self.errorMessage = ""
    }
    
    // MARK: - Google Sign-In
    public func completeGoogleSignIn(with result: GIDSignInResult) async {
        print("➡️ Starting completeGoogleSignIn...")

        let user = result.user

        do {
            let authentication = try await user.refreshTokensIfNeeded()
            let accessToken = authentication.accessToken.tokenString
            let idToken = authentication.idToken?.tokenString

            // Log token strings
            print("🔑 Access Token: \(accessToken)")
            print("🔑 ID Token: \(idToken ?? "nil")")

            // Decode ID token payload for debugging
            if let tokenString = idToken,
               let decoded = decodeJWTPart(tokenString) {
                print("🧾 Decoded ID Token Payload: \(decoded)")
            }

            // User profile info
            let email = user.profile?.email ?? "N/A"
            let name = user.profile?.name ?? "N/A"
            let userID = user.userID
            print("""
            🔍 Google Sign-In Result:
            - User ID: \(userID ?? "Missing User ID")
            - Name: \(name)
            - Email: \(email)
            """)

            // Require ID token to continue
            guard let idTokenString = idToken else {
                print("❌ Missing ID token from Google user.")
                handleSignInError(nil, message: "Google Sign-In failed: No ID token.")
                return
            }

            print("🔐 Tokens ready – ID Token prefix: \(idTokenString.prefix(20)), Access Token prefix: \(accessToken.prefix(20))")

            await signInToFirebase(idToken: idTokenString, accessToken: accessToken)

            updateSocialUser(
                user.userID,
                name,
                email,
                profilePictureUrl: user.profile?.imageURL(withDimension: 200),
                provider: .google
            )

            print("✅ completeGoogleSignIn finished. Current user: \(self.socialUser?.email ?? "nil")")
        } catch {
            print("❌ Error refreshing tokens: \(error)")
            handleSignInError(error, message: "Google Sign-In failed: No authentication object.")
            return
        }
    }
    
    // MARK: - Facebook Sign-In
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
    
    // MARK: - Firebase Sign-In
    internal func signInToFirebase(with credential: AuthCredential) async throws {
        let result = try await Auth.auth().signIn(with: credential)
        await handleSuccessfulLogin(provider: detectProvider(from: credential), user: result.user)
    }

    public func signInToFirebase(idToken: String, accessToken: String) async {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        do {
            print("📤 Signing in to Firebase with Google credentials...")
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Firebase sign-in success – UID: \(authResult.user.uid)")
            await handleSuccessfulLogin(provider: .google, user: authResult.user)
            
        } catch {
            let nsError = error as NSError
            print("❌ Firebase sign-in failed!")
            print("🧵 NSError domain: \(nsError.domain), code: \(nsError.code)")
            print("📄 Full error: \(error.localizedDescription)")
            handleSignInError(error)
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
    }
    
    func handleSignInError(_ error: Error?, message: String? = nil) {
        self.hasError = true
        self.errorMessage = message ?? error?.localizedDescription ?? "Unknown error."

        print("🚨 Sign-In Error: \(self.errorMessage)")

        if let nsError = error as NSError? {
            print("📦 NSError - Domain: \(nsError.domain), Code: \(nsError.code)")
            print("🔍 UserInfo: \(nsError.userInfo)")
        }
    }

    
    // MARK: - Authentication Status
    private func updateAuthenticationStatus() {
        self.isAuthenticated = (userInfo != nil || currentUser != nil || socialUser != nil)
        self.isLoggedIn = isAuthenticated
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

        if salt.isEmpty || hash.isEmpty {
            print("⚠️ Warning: Extracted salt or hash is empty.")
            throw HashError.invalidInput
        }

        return HashedPassword(hash: hash, salt: salt, iterations: 8)
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
   
    
}

extension SocialUser.Provider: CustomStringConvertible {
    public var description: String {
        switch self {
        case .google: return "Google"
        case .facebook: return "Facebook"
        // Future-proofing: handles any new providers added without breaking
        @unknown default: return "Unknown Provider"
        }
    }
}
