//
//  hashPassword.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import Security
import CryptoSwift

// Hashing.swift
enum HashError: Error {
    case invalidInput
    case coreDataError(Error)
    case passwordVerificationError
}

// Firebase PBKDF2 configuration
let firebaseHashConfig: [String: Any] = [
    "algorithm": "PBKDF2",
    "base64SignerKey": "Kt5JkNrRAeub1x2rDuCq1BYKmVIOfTTeRyPQAItJzO4gfCfg9JRzWTkC1wKGIoEUZ9N2CZY6DtXwK9s81ZpdvA==",
    "base64SaltSeparator": "Bw==",
    "rounds": 8,
    "memCost": 14
]

// HashConfig.swift
struct HashConfig {
    let separator: Data
    let rounds: Int
    let saltLength: Int
    let keyLength: Int
    
    init() {
        guard let base64SaltSeparator = firebaseHashConfig["base64SaltSeparator"] as? String else {
            fatalError("Missing 'base64SaltSeparator' value in firebaseHashConfig")
        }
        separator = Data(base64Encoded: base64SaltSeparator, options: .ignoreUnknownCharacters)!
        
        guard let roundsValue = firebaseHashConfig["rounds"] as? Int else {
            fatalError("Missing 'rounds' value in firebaseHashConfig")
        }
        rounds = roundsValue
        
        // Initialize saltLength and keyLength
        saltLength = 16
        keyLength = 32
    }
}

let hashConfig = HashConfig()
let saltLength = 16
let keyLength = 32 // Default key length for PBKDF2



// HashedPassword.swift
struct HashedPassword {
    let salt: Data
    let iterations: Int
    let hash: Data
}

// Hash password using PBKDF2
func hashPasswordPbkdf(_ password: String) throws -> HashedPassword {
    guard let passwordData = password.data(using: .utf8) else {
        throw HashError.invalidInput
    }
    
    let salt = try generateSalt(length: saltLength)
    
    // PBKDF2 implementation using CryptoSwift
    let pbkdf = try PKCS5.PBKDF2(password: passwordData.bytes, salt: salt.bytes, iterations: hashConfig.rounds, keyLength: keyLength, variant: .sha2(.sha256))
    let derivedKey = try pbkdf.calculate()
    
    // Combine salt and derived key
    let combined = hashConfig.separator + Data(derivedKey) + salt
    
    return HashedPassword(salt: salt, iterations: hashConfig.rounds, hash: combined)
}

// Generate random salt
func generateSalt(length: Int = HashConfig().saltLength) throws -> Data {
    var bytes = [UInt8](repeating: 0, count: length)
    let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
    
    if status != errSecSuccess {
        throw HashError.invalidInput
    }
    
    return Data(bytes)
}

// Verify password using PBKDF2
func verifyPasswordPbkdf(_ inputPassword: String, againstHash storedHash: HashedPassword) throws -> Bool {
    let saltData = storedHash.salt
    let hashData = storedHash.hash
    
    let pbkdf = try PKCS5.PBKDF2(
        password: Array(inputPassword.utf8),
        salt: saltData.bytes,
        iterations: storedHash.iterations,
        keyLength: hashData.count,
        variant: .sha2(.sha256)
    )
    let derivedKey = try pbkdf.calculate()
    
    return Data(derivedKey) == hashData
}
    
