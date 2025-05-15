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
import GoogleSignInSwift
import FBSDKLoginKit
import GoogleSignIn

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
public class AuthenticationState: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated: Bool = false
    @Published var isAdmin: Bool = false
    @Published public private(set) var socialUser: SocialUser?
    @Published public private(set) var userInfo: UserInfo?
    @Published public private(set) var currentUser: User?
    @Published var errorMessage: String = ""
    @Published var hasError: Bool = false
    @Published var isLoggedIn: Bool = false
    @Published var navigateToAdminMenu: Bool = false

    // MARK: - Private Properties
    private let validator: Validator
    private let hashPassword: PasswordHasher

    // MARK: - Initializer
    public init(hashPassword: PasswordHasher, validator: Validator = EmailValidator()) {
        self.hashPassword = hashPassword
        self.validator = validator
    }

    // MARK: - CoreData Login
    public func login(_ user: UserInfo, password: String) throws {
        print("🔐 Attempting CoreData login for \(user.email)")

        guard validator.isValidEmail(user.email) else {
            throw AuthenticationError.invalidEmail
        }

        guard !user.passwordHash.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }

        do {
            let hashedPassword = try convertToHashedPassword(user.passwordHash)
            if try !hashPassword.verifyPasswordScrypt(password, againstHash: hashedPassword) {
                throw AuthenticationError.invalidPassword
            }
        } catch {
            throw AuthenticationError.serverError
        }

        guard user.isVerified else {
            throw AuthenticationError.unverifiedEmail
        }

        self.userInfo = user
        self.currentUser = nil
        updateAuthenticationStatus()
        isLoggedIn = true
        print("✅ CoreData login successful for \(user.email)")

    }

    // MARK: - Firestore Login
    public func login(user: User) {
        self.currentUser = user
        self.userInfo = nil
        updateAuthenticationStatus()
        isLoggedIn = true
        print("✅ Logged in as Firestore user: \(user.userName)")
    }

    // MARK: - Logout
    public func logout(completion: @escaping () -> Void = {}) {
        self.userInfo = nil
        self.currentUser = nil
        self.socialUser = nil
        self.isAuthenticated = false
        self.isLoggedIn = false
        self.isAdmin = false
        completion()
        print("🔒 User logged out.")
    }

    // MARK: - Social Sign-In
    public func signInWith(provider: SocialUser.Provider) async {
        switch provider {
        case .google: await signInWithGoogle()
        case .facebook: await signInWithFacebook()
        }
    }

    // MARK: - Google Sign-In (Modern async/await approach)
    @MainActor
    func signInWithGoogle() async {
        print("📲 Starting Google Sign-In flow...")

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            print("❗ No root view controller found. Aborting Google Sign-In.")
            return
        }

        do {
            print("🔄 Presenting Google Sign-In UI...")
            let gidResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            let user = gidResult.user

            // Log basic user info
            print("✅ Google Sign-In successful:")
            print("   - Name: \(user.profile?.name ?? "nil")")
            print("   - Email: \(user.profile?.email ?? "nil")")
            print("   - UserID: \(user.userID ?? "nil")")

            guard let idToken = user.idToken?.tokenString,
                  let accessToken = user.accessToken.tokenString as String? else {
                print("❌ Missing tokens from Google user.")
                handleSignInError(NSError(domain: "GoogleSignIn", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Missing authentication tokens."
                ]))
                return

            }

            // Delegate sign-in to Firebase
            await signInToFirebase(idToken: idToken, accessToken: accessToken)

            // Update local app state
            updateSocialUser(
                user.userID,
                user.profile?.name ?? "Unknown",
                user.profile?.email ?? "Unknown",
                profilePictureUrl: user.profile?.imageURL(withDimension: 200),
                provider: .google
            )
            print("🧠 Updated app state with Google user info.")

        } catch {
            print("❌ Google Sign-In or Firebase auth failed.")
            print("📛 \(error.localizedDescription)")
            handleSignInError(error)
        }
    }


    
    @MainActor
    func completeGoogleSignIn(with result: GIDSignInResult) async {
        // Optionally log the ID token or use it for Firebase Auth
        guard let idToken = result.user.idToken?.tokenString else {
            self.errorMessage = "Missing ID token."
            self.hasError = true
            return
        }

        print("🔐 Received ID token: \(idToken.prefix(10))...") // Don't log full token in production

        // If using Firebase:
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Firebase sign-in successful: \(authResult.user.email ?? "unknown")")
            self.hasError = false
        } catch {
            print("❌ Firebase sign-in failed: \(error.localizedDescription)")
            self.hasError = true
            self.errorMessage = error.localizedDescription
        }
    }


    // MARK: - Facebook Sign-In
    func signInWithFacebook() async {
        do {
            guard let accessToken = AccessToken.current else {
                throw NSError(domain: "MF_inder", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Facebook login failed. Please try again."
                ])
            }

            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
            try await signInToFirebase(with: credential)
        } catch {
            print("❌ Facebook Sign-In failed with error: \(error.localizedDescription)")
            handleSignInError(error)
        }
    }

    // MARK: - Helper Functions
    private func handleSignInError(_ error: Error?) {
        DispatchQueue.main.async {
            self.hasError = true
            self.errorMessage = error?.localizedDescription ?? "An unknown error occurred."
        }

        guard let error = error else {
            print("❗ handleSignInError called with nil error.")
            return
        }

        print("🚨 Error occurred during Google Sign-In:")
        print("🧵 Error Type: \(type(of: error))")
        print("📝 Description: \(error.localizedDescription)")
        print("📛 Full Error Object: \(error)")

        if let nsError = error as NSError? {
            print("📦 NSError Details:")
            print("   - Domain: \(nsError.domain)")
            print("   - Code: \(nsError.code)")
            print("   - UserInfo: \(nsError.userInfo)")
        }
    }


    internal func signInToFirebase(with credential: AuthCredential) async throws {
        let result = try await Auth.auth().signIn(with: credential)
        await handleSuccessfulLogin(provider: detectProvider(from: credential), user: result.user)
    }

    
    @MainActor
    func signInToFirebase(idToken: String, accessToken: String) async {
        #if DEBUG
        print("🔐 ID Token (prefix): \(idToken.prefix(10))...")
        print("🔐 Access Token (prefix): \(accessToken.prefix(10))...")
        #endif

        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        do {
            print("🔥 Signing in to Firebase...")
            let authResult = try await Auth.auth().signIn(with: credential)
            print("✅ Firebase sign-in success. UID: \(authResult.user.uid)")

            handleSuccessfulLogin(provider: .google, user: authResult.user)

        } catch {
            print("❌ Firebase sign-in failed: \(error.localizedDescription)")
            handleSignInError(error)
        }
    }


    
    private func detectProvider(from credential: AuthCredential) -> SocialUser.Provider {
        switch credential.provider {
        case "google.com": return .google
        case "facebook.com": return .facebook
        default: return .google // fallback
        }
    }


    @MainActor
    func updateSocialUser(
        _ userID: String?,
        _ name: String,
        _ email: String,
        profilePictureUrl: URL?,
        provider: SocialUser.Provider
    ) {
        guard let userID = userID, !name.isEmpty, !email.isEmpty else {
            self.errorMessage = "Missing user information from social login. Please try again."
            self.hasError = true
            print("⚠️ Social sign-in failed: userID = \(String(describing: userID)), name = '\(name)', email = '\(email)'")
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
    }


    @MainActor
    private func handleSuccessfulLogin(provider: SocialUser.Provider, user: FirebaseAuth.User?, googleUser: GIDGoogleUser? = nil) {
        guard let user = user else {
            print("❌ Firebase user is nil after sign-in.")
            self.errorMessage = "Failed to retrieve user information."
            self.hasError = true
            return
        }

        print("✅ Firebase user retrieved: \(user.email ?? "Unknown email") (\(provider))")
        if let googleUser = googleUser {
            updateSocialUser(
                googleUser.userID,
                googleUser.profile?.name ?? "Unknown",
                googleUser.profile?.email ?? "No Email",
                profilePictureUrl: googleUser.profile?.imageURL(withDimension: 200),
                provider: .google
            )
        } else {
            updateSocialUser(
                user.uid,
                user.displayName ?? "Unknown",
                user.email ?? "No Email",
                profilePictureUrl: user.photoURL,
                provider: provider
            )
        }
    }

    private func updateAuthenticationStatus() {
        if let user = userInfo {
            isAuthenticated = user.isVerified
        } else if currentUser != nil || socialUser != nil {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }

    private func convertToHashedPassword(_ passwordHash: Data) throws -> HashedPassword {
        let separatorData = Data(hashPassword.base64SaltSeparator.utf8)
        guard let separatorIndex = passwordHash.range(of: separatorData)?.lowerBound else {
            throw HashError.invalidInput
        }

        let salt = passwordHash[..<separatorIndex]
        let hash = passwordHash[separatorIndex...].dropFirst(separatorData.count)
        return HashedPassword(hash: hash, salt: salt, iterations: 8)
    }
}
