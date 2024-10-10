// hashPassword.swift
// Seas_3
//
// Created by Brian Romero on 10/8/24.
//


import Foundation
import Security
import CryptoSwift


// Error types for password hashing
enum HashError: Error {
    case invalidInput
}

// Structure for storing the password hash and associated data
struct PasswordHash: Codable {
    let salt: Data
    let iterations: Int
    let hash: Data
}

// Generates random data for salt.
func generateSalt(length: Int = 32) -> Data {
    var bytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
    
    if status != errSecSuccess {
        print("Error generating salt: \(status)")
        // Consider throwing an error or returning a default value
    }
    
    return Data(bytes)
}

// Hashes a password using PBKDF2 with HMAC SHA-512.
func hashPassword(_ password: String) throws -> PasswordHash {
    guard let passwordData = password.data(using: .utf8) else {
        throw HashError.invalidInput
    }
    
    let salt = generateSalt(length: 16)
    let iterations = 10000
    
    // Using PBKDF2 directly from CryptoSwift
    let pbkdf2 = try PKCS5.PBKDF2(password: passwordData.bytes, salt: salt.bytes, iterations: iterations, keyLength: 32, variant: .sha2(.sha512))
    let derivedKey = try pbkdf2.calculate()
    
    return PasswordHash(salt: salt, iterations: iterations, hash: Data(derivedKey))
}

// Verifies a password against a stored hash.
func verifyPassword(_ password: String, againstHash passwordHash: PasswordHash) throws -> Bool {
    guard let passwordData = password.data(using: .utf8) else {
        throw HashError.invalidInput
    }
    
    // Using PBKDF2 directly from CryptoSwift
    let pbkdf2 = try PKCS5.PBKDF2(password: passwordData.bytes, salt: passwordHash.salt.bytes, iterations: passwordHash.iterations, keyLength: 32, variant: .sha2(.sha512))
    let derivedKey = try pbkdf2.calculate()
    
    return Data(derivedKey) == passwordHash.hash
}


// User class to store the email and hashed password
class User {
    var email: String
    var username: String // Make username a required property
    var passwordHash: PasswordHash?
    
    init(email: String, username: String, passwordHash: PasswordHash?) {
        self.email = email
        self.username = username
        self.passwordHash = passwordHash
    }
}


// Example usage of the hashing and verification functions
class EmailSignOn {
    func exampleUsage() {
        // Storing hashed password
        let userPassword = "mysecretpassword"
        do {
            let hashedPassword = try hashPassword(userPassword)
            // Provide a username when initializing the User object
            let user = User(email: "user@example.com", username: "user123", passwordHash: hashedPassword)
            
            // Retrieving hashed password
            let inputPassword = "mysecretpassword"
            if let userPasswordHash = user.passwordHash {
                if try verifyPassword(inputPassword, againstHash: userPasswordHash) {
                    print("Password is valid")
                } else {
                    print("Password is invalid")
                }
            } else {
                print("User password hash is missing")
            }
        } catch {
            print("Error: \(error)")
        }
    }
}
