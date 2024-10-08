//
// hashPassword.swift
// Seas_3
//
// Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import CryptoKit

// Password hashing and verification functions

/// Hashes a password using SHA256.
///
/// - Parameter password: The password to be hashed.
/// - Returns: The hashed password as Data.
func hashPassword(_ password: String) -> Data? {
    Data(password.utf8).withUnsafeBytes { buffer in
        SHA256.hash(data: buffer).withUnsafeBytes { digestBuffer in
            Data(digestBuffer)
        }
    }
}

/// Verifies a password against a stored hash.
///
/// - Parameters:
///   - password: The password to verify.
///   - hash: The stored hash to verify against.
/// - Returns: True if the password matches the hash, false otherwise.
func verifyPassword(_ password: String, againstHash hash: Data) -> Bool {
    guard let hashedPassword = hashPassword(password) else { return false }
    return hashedPassword == hash
}

// User class
class User {
    var email: String
    var passwordHash: Data?
    
    init(email: String, passwordHash: Data?) {
        self.email = email
        self.passwordHash = passwordHash
    }
}

class EmailSignOn {
    func exampleUsage() {
        // Storing hashed password
        let userPassword = "mysecretpassword"
        if let hashedPassword = hashPassword(userPassword) {
            let user = User(email: "user@example.com", passwordHash: hashedPassword)
            
            // Retrieving hashed password
            let inputPassword = "mysecretpassword"
            if let userPasswordHash = user.passwordHash {
                if verifyPassword(inputPassword, againstHash: userPasswordHash) {
                    print("Password is valid")
                } else {
                    print("Password is invalid")
                }
            } else {
                print("User password hash is missing")
            }
        } else {
            print("Failed to hash password")
        }
    }
}
