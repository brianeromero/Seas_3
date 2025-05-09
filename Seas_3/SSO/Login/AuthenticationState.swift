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


// MARK: - Validator
public protocol Validator {
    func isValidEmail(_ email: String) -> Bool
}



// MARK: - AuthenticationState
public class AuthenticationState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isAdmin: Bool = false
    @Published public private(set) var socialUser: SocialUser?
    
    /// Optional: store either CoreData UserInfo or Firestore User struct
    @Published var userInfo: UserInfo?
    @Published var currentUser: User?

    @Published var errorMessage: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var navigateToAdminMenu: Bool = false

    private let validator: Validator
    private let hashPassword: PasswordHasher

    public init(hashPassword: PasswordHasher, validator: Validator = EmailValidator()) {        self.hashPassword = hashPassword
        self.validator = validator
    }

    // MARK: - CoreData Login
    public func login(_ user: UserInfo, password: String) throws {
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
    public func signInWith(provider: SocialUser.Provider) {
        switch provider {
        case .google: signInWithGoogle()
        case .facebook: signInWithFacebook()
        }
    }

    // MARK: - Helper Methods
    
    private func handleSignInError(_ error: Error?) {
         DispatchQueue.main.async {
             self.errorMessage = error?.localizedDescription ?? "An unknown error occurred."
         }
     }
    
    private func updateSocialUser(_ userId: String, _ userName: String, _ userEmail: String, profilePictureUrl: URL?, provider: SocialUser.Provider) {
        guard !userId.isEmpty, !userName.isEmpty, !userEmail.isEmpty else {
            handleSignInError(nil)
            return
        }

        let socialUser = SocialUser(provider: provider, id: userId, name: userName, email: userEmail, profilePictureUrl: profilePictureUrl)
        DispatchQueue.main.async {
            self.socialUser = socialUser
            self.isAuthenticated = true
            self.isLoggedIn = true
        }
    }
    
  
    private func authenticateWithFirebase(credential: AuthCredential, provider: SocialUser.Provider) {
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                self.handleSignInError(error)
            } else {
                self.handleSuccessfulLogin(provider: provider, user: authResult?.user)
            }
        }
    }
    
    private func handleSuccessfulLogin(provider: SocialUser.Provider, user: FirebaseAuth.User?) {
        guard let user = user else {
            self.errorMessage = "Failed to retrieve user information."
            return
        }

        updateSocialUser(user.uid, user.displayName ?? "Unknown", user.email ?? "No Email", profilePictureUrl: user.photoURL, provider: provider)
    }

    // MARK: - Google Sign-In
    
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let rootVC = getRootViewController() else { return }
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                self.handleSignInError(error)
                return
            }

            guard let user = result?.user, let idToken = user.idToken else {
                self.errorMessage = "Google sign-in failed."
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString, accessToken: user.accessToken.tokenString)
            self.authenticateWithFirebase(credential: credential, provider: .google)
        }
    }
    
    // MARK: - Facebook Sign-In
    
    func signInWithFacebook() {
        if let accessToken = AccessToken.current {
            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
            authenticateWithFirebase(credential: credential, provider: .facebook)
        } else {
            self.errorMessage = "Facebook login failed. Please try again."
        }
    }
    
    // MARK: - Helper Functions

    private func convertToHashedPassword(_ passwordHash: Data) throws -> HashedPassword {
        let separatorData = Data(hashPassword.base64SaltSeparator.utf8)
        guard let separatorIndex = passwordHash.range(of: separatorData)?.lowerBound else {
            throw HashError.invalidInput
        }

        let salt = passwordHash[..<separatorIndex]
        let hash = passwordHash[separatorIndex...].dropFirst(separatorData.count)
        return HashedPassword(hash: hash, salt: salt, iterations: 8)
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

    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}

// MARK: - SocialUser

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
