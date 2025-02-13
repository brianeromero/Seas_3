//
//  AuthenticationState.swift
//  Seas_3
//
//  Created by Brian Romero on 10/5/24.
//

import Foundation
import SwiftUI
import Combine
import Firebase
import FirebaseAuth
import GoogleSignIn
import FBSDKLoginKit


// MARK: - Validator

/// A protocol for validating user input.
public protocol Validator {
    /// Validates an email address.
    ///
    /// - Parameter email: The email address to validate.
    ///
    /// - Returns: Whether the email address is valid.
    func isValidEmail(_ email: String) -> Bool
}


/// Manages the authentication state of the application.
public class AuthenticationState: ObservableObject {
    /// Indicates whether the user is authenticated.
    @Published var isAuthenticated: Bool = false
    
    /// Indicates whether the user has admin access.
    @Published var isAdmin: Bool = false
    
    /// The social user information.
    @Published public private(set) var socialUser: SocialUser?
    
    /// The user information.
    @Published var user: UserInfo?
    
    /// The error message to display.
    @Published var errorMessage: String = ""
    
    /// Indicates whether the user is logged in.
    @Published var isLoggedIn: Bool = false
    
    /// Indicates whether to navigate to the admin menu.
    @Published var navigateToAdminMenu: Bool = false
    
    private let validator: Validator
    private let hashPassword: HashPassword

    /// Initializes the authentication state with the given validator and hash password.
    init(hashPassword: HashPassword = HashPassword(), validator: Validator = EmailValidator()) {
        self.hashPassword = hashPassword
        self.validator = validator
    }
    
    
    // MARK: - Authentication
    
    /// Logs in a user with the provided credentials.
    ///
    /// - Parameters:
    ///   - user: The user to log in.
    ///   - password: The password to authenticate with.
    ///
    /// - Throws: AuthenticationError if the login fails.
    public func login(_ user: UserInfo, password: String) throws {
        // Validate the email address
        guard validator.isValidEmail(user.email) else {
            throw AuthenticationError.invalidEmail
        }
        
        // Check if the password hash is empty
        guard !user.passwordHash.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        
        do {
            // Convert the password hash to a hashed password
            let hashedPassword = try convertToHashedPassword(user.passwordHash)
            
            // Verify the password using SCRYPT
            if try !hashPassword.verifyPasswordScrypt(password, againstHash: hashedPassword) {
                throw AuthenticationError.invalidPassword
            }
        } catch {
            print("Login error: \(error.localizedDescription)")
            // Throw a server error if the password verification fails
            throw AuthenticationError.serverError
        }
        
        // Check if the user's email address is verified
        guard user.isVerified else {
            throw AuthenticationError.unverifiedEmail
        }
        
        // Update the user and authentication status
        self.user = user
        updateAuthenticationStatus()
        isLoggedIn = true
        
        // Log the successful login
        print("User logged in successfully")
    }
    
    /// Signs in with a specified provider (Google or Facebook).
    ///
    /// - Parameter provider: The provider to sign in with.
    func signInWith(provider: SocialUser.Provider) {
        switch provider {
        case .google:
            print("Google Sign-In button pressed")
            signInWithGoogle() // Simplified Google Sign-In call
        case .facebook:
            print("Facebook Sign-In button pressed")
            signInWithFacebook() // Simplified Facebook Sign-In call
        }
    }

    // MARK: - Helper Methods
    
    /// Handles sign-in errors.
    ///
    /// - Parameter error: The error to handle.
    private func handleSignInError(_ error: Error?) {
        // Display the error message
        DispatchQueue.main.async {
            self.errorMessage = error?.localizedDescription ?? "An unknown error occurred."
        }
        
        // Log the error
        print("Sign-in error: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    /// Updates the social user information.
    ///
    /// - Parameters:
    ///   - userId: The user's ID.
    ///   - userName: The user's name.
    ///   - userEmail: The user's email address.
    ///   - profilePictureUrl: The user's profile picture URL.
    ///   - provider: The provider used to sign in.
    private func updateSocialUser(_ userId: String, _ userName: String, _ userEmail: String, profilePictureUrl: URL? = nil, provider: SocialUser.Provider) {
        // Check if the social user is already set
        if socialUser != nil {
            print("Social user is already set")
            return
        }
        
        // Ensure the user ID, name, and email address are not empty
        guard !userId.isEmpty, !userName.isEmpty, !userEmail.isEmpty else {
            handleSignInError(nil)
            return
        }
        
        // Create the social user object
        let socialUser = SocialUser(provider: provider, id: userId, name: userName, email: userEmail, profilePictureUrl: profilePictureUrl)
        
        // Update the social user property on the main thread
        DispatchQueue.main.async {
            self.socialUser = socialUser
            self.isAuthenticated = true
            self.isLoggedIn = true
            
            // Log the successful social user update
            print("Social user updated successfully")
            print("Social user updated: \(SocialUser(provider: provider, id: userId, name: userName, email: userEmail, profilePictureUrl: profilePictureUrl))")
        }
    }
    
    // MARK: - Logout
    
    /// Logs out the current user.
    ///
    /// - Parameter completion: A completion handler to call after logging out.
    public func logout(completion: @escaping () -> Void = {}) {
        print("AuthenticationState.logout() called!") // Debugging

        // Reset user authentication state
        self.user = nil
        self.socialUser = nil
        self.isAuthenticated = false
        self.isAdmin = false
        isLoggedIn = false

        print("User logged out successfully from AuthenticationState")

        // Call the completion handler
        completion()
    }
    
    // MARK: - Firebase Authentication
    /// Authenticates with Firebase using the given credential.
    ///
    /// - Parameters:
    ///   - credential: The credential to use for authentication.
    ///   - provider: The provider used to sign in.
    private func authenticateWithFirebase(credential: AuthCredential, provider: SocialUser.Provider) {
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error = error {
                print("Firebase authentication error: \(error.localizedDescription)")
                self.handleSignInError(error)
            } else {
                self.handleSuccessfulLogin(provider: provider, user: authResult?.user)
            }
        }
    }
    
    /// Handles successful login.
    ///
    /// - Parameters:
    ///   - provider: The provider used to sign in.
    ///   - user: The user who signed in.
    private func handleSuccessfulLogin(provider: SocialUser.Provider, user: FirebaseAuth.User?) {
        // Get the user's information
        guard let user = user else {
            // Handle the error
            self.errorMessage = "Failed to retrieve user information."
            return
        }
        
        // Update the social user information
        updateSocialUser(user.uid, user.displayName ?? "Unknown", user.email ?? "No Email", profilePictureUrl: user.photoURL, provider: provider)
    }
    
    // MARK: - Google Sign-In
    
    /// Signs in with Google.
    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let rootViewController = getRootViewController() else { return }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: nil
        ) { result, error in
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
    
    /// Signs in with Facebook.
    func signInWithFacebook() {
        if let accessToken = AccessToken.current {
            let credential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
            authenticateWithFirebase(credential: credential, provider: .facebook) // Directly authenticate
        } else {
            print("Facebook Access Token not found.")
            // Handle the case where the access token is missing, e.g., show an error message.
            self.errorMessage = "Facebook login failed. Please try again."
        }
    }
    
    // MARK: - Helper Functions
    
    /// Converts a password hash to a hashed password.
    ///
    /// - Parameter passwordHash: The password hash to convert.
    ///
    /// - Returns: The hashed password.
    ///
    /// - Throws: HashError if the conversion fails.
    private func convertToHashedPassword(_ passwordHash: Data) throws -> HashedPassword {
        let separatorData = Data(hashPassword.base64SaltSeparator.utf8)
        
        guard let separatorIndex = passwordHash.range(of: separatorData)?.lowerBound else {
            throw HashError.invalidInput // Reference HashError from Hashing.swift
        }
        
        let salt = passwordHash[..<separatorIndex]
        let hash = passwordHash[separatorIndex...].dropFirst(separatorData.count)
        
        return HashedPassword(hash: hash, salt: salt, iterations: 8)
    }
    
    /// Updates the authentication status.
    private func updateAuthenticationStatus() {
        isAuthenticated = user != nil && user?.isVerified ?? false
        print("Authentication status updated: \(isAuthenticated)")
    }
    
    /// Gets the root view controller.
    ///
    /// - Returns: The root view controller.
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
    }
}
 
// MARK: - Social User

/// Represents a social user.
public struct SocialUser {
    /// The provider used to sign in.
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

/// A validator for email addresses.
public class EmailValidator: Validator {
    /// Validates an email address.
    ///
    /// - Parameter email: The email address to validate.
    ///
    /// - Returns: Whether the email address is valid.
    public func isValidEmail(_ email: String) -> Bool {
        // Implement email validation logic here
        // For example:
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
