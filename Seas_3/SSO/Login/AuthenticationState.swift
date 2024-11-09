//
//  AuthenticationState.swift
//  Seas_3
//
//  Created by Brian Romero on 10/5/24.
//

import Foundation
import SwiftUI
import Combine

/// Manages the authentication state of the application.
public class AuthenticationState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isAdmin: Bool = false // Existing admin access indicator
    @Published public private(set) var socialUser: SocialUser?
    @Published var user: UserInfo?
    @Published var errorMessage: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var navigateToAdminMenu: Bool = false

    var isValidAuthentication: Bool {
        guard let user = user else { return false }
        return user.isVerified &&
               // Other conditions...
               self.user != nil &&
               self.errorMessage.isEmpty
    }

    /// Represents a social user.
    public struct SocialUser {
        /// Social provider (e.g., Facebook, Google).
        public enum Provider: String, CaseIterable {
            case facebook = "Facebook"
            case google = "Google"
        }
        
        let provider: Provider
        let id: String
        let name: String
        let email: String
        let profilePictureUrl: URL?
        
        /// Initializes a social user.
        ///
        /// - Parameters:
        ///   - provider: Social provider.
        ///   - id: User's ID.
        ///   - name: User's name.
        ///   - email: User's email.
        ///   - profilePictureUrl: User's profile picture URL (optional).
        init(provider: Provider, id: String, name: String, email: String, profilePictureUrl: URL? = nil) {
            self.provider = provider
            self.id = id
            self.name = name
            self.email = email
            self.profilePictureUrl = profilePictureUrl
        }
    }

    public init(errorMessage: String = "") {
        self.errorMessage = errorMessage
    }

    /// Checks if an email address is valid.
    ///
    /// - Parameter email: Email address to validate.
    /// - Returns: True if the email is valid, false otherwise.
    private func isValidEmail(_ email: String) -> Bool {
        return ValidationUtility.validateField(email, type: .email) == nil
    }

    /// Checks if a password is valid.
    ///
    /// - Parameter password: Password to validate.
    /// - Returns: True if the password is valid, false otherwise, along with an optional error message.
    private func isValidPassword(_ password: String) -> (Bool, String?) {
        let isValid = ValidationUtility.isValidPassword(password) == nil
        let feedback = ValidationUtility.isValidPassword(password)?.localizedDescription
        return (isValid, feedback ?? "Invalid password")
    }

    /// Updates the social user with the provided information.
    ///
    /// - Parameters:
    ///   - provider: Social provider.
    ///   - userId: User's ID.
    ///   - userName: User's name.
    ///   - userEmail: User's email.
    ///
    /// - Throws: AuthenticationError.invalidUserData if any parameters are empty.
    public func updateSocialUser(_ provider: SocialUser.Provider, _ userId: String, _ userName: String, _ userEmail: String) throws {
        guard !userId.isEmpty, !userName.isEmpty, !userEmail.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        
        socialUser = SocialUser(provider: provider, id: userId, name: userName, email: userEmail)
        isAuthenticated = true
    }

    /// Resets the social user.
    public func resetSocialUser() {
        socialUser = nil
        isAuthenticated = false
    }

    /// Resets the Facebook user.
    public func resetFacebookUser() {
        resetSocialUser()
    }

    /// Logs in a user with the provided credentials.
    ///
    /// - Parameters:
    ///   - user: User to log in.
    ///   - password: Password to authenticate with.
    ///
    /// - Throws: AuthenticationError.invalidEmail, AuthenticationError.invalidPassword, or AuthenticationError.serverError.
    public func login(_ user: UserInfo, password: String) throws {
        guard isValidEmail(user.email) else {
            throw AuthenticationError.invalidEmail
        }
        guard !user.passwordHash.isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        
        do {
            // Convert user.passwordHash (Data) to HashedPassword
            let hashedPassword = try convertToHashedPassword(user.passwordHash)
            
            if try !verifyPasswordPbkdf(password, againstHash: hashedPassword) {
                throw AuthenticationError.invalidPassword
            }
        } catch {
            throw AuthenticationError.serverError
        }
        
        // Check if email is verified
        guard user.isVerified else {
            throw AuthenticationError.unverifiedEmail
        }
        
        // Set user and update authentication state
        self.user = user
        updateAuthenticationStatus()
        isLoggedIn = true
    }


    // Helper function to convert Data to HashedPassword
    private func convertToHashedPassword(_ passwordHash: Data) throws -> HashedPassword {
        // Separate salt and hash
        guard let separatorIndex = passwordHash.firstIndex(of: hashConfig.separator.first!) else {
            throw HashError.invalidInput
        }
        
        let salt = passwordHash.prefix(upTo: separatorIndex)
        let hash = passwordHash.suffix(from: separatorIndex + hashConfig.separator.count)
        
        return HashedPassword(salt: salt, iterations: hashConfig.rounds, hash: hash)
    }

    /// Logs out the current user.
    ///
    /// - Parameter completion: Optional completion handler.
    public func logout(completion: () -> Void = {}) {
        self.user = nil
        resetSocialUser()           // Clear any social user info
        updateAuthenticationStatus() // Relies on `user` being nil to set `isAuthenticated` to false
        resetAdminState()            // Reset admin-related properties
        completion()
    }


    func updateAuthenticationStatus() {
        isAuthenticated = (user != nil)
    }


    /// Resets the admin state when logging out.
    public func resetAdminState() {
        isAdmin = false
    }
}
