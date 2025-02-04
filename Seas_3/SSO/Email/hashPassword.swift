//
//  hashPassword.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import CryptoSwift

// Hashing.swift
enum HashError: Error {
    case invalidInput
    case coreDataError(Error)
    case passwordVerificationError
}

class HashPassword {
    // Firebase Authentication Scrypt configuration
    let algorithm = "SCRYPT"
    let base64SignerKey = "Kt5JkNrRAeub1x2rDuCq1BYKmVIOfTTeRyPQAItJzO4gfCfg9JRzWTkC1wKGIoEUZ9N2CZY6DtXwK9s81ZpdvA=="
    let base64SaltSeparator = "Bw=="
    let rounds = 8
    let memCost = 14

    // Convert base64 signer key to Data
    let signerKeyData: Data
    
    init() {
        guard let data = Data(base64Encoded: base64SignerKey) else {
            fatalError("Failed to convert base64 signer key to Data")
        }
        signerKeyData = data
    }
    
    // Hash password using Scrypt
    func hashPasswordScrypt(_ password: String) throws -> HashedPassword {
        // Generate random salt
        let salt = try generateSalt(ofLength: 16)
        
        // Hash password using Scrypt
        let scrypt = try! Scrypt(password: Array(password.utf8), salt: Array(salt), dkLen: 32, N: Int(pow(2, Double(memCost))), r: rounds, p: 1)
        let hashedPassword = try scrypt.calculate()
        
        // Return the HashedPassword struct (hash, salt, iterations)
        let hashedPasswordData = Data(hashedPassword)
        return HashedPassword(hash: hashedPasswordData, salt: Data(salt), iterations: memCost) // `memCost` used as iterations
    }

    
    // Generate random salt
    func generateSalt(ofLength length: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        
        if status != errSecSuccess {
            throw HashError.invalidInput
        }
        
        return Data(bytes)
    }
    
    // Verify password using SCRYPT (Updated version)
    func verifyPasswordScrypt(_ inputPassword: String, againstHash storedHash: HashedPassword) throws -> Bool {
        // Hash input password using Scrypt
        let scrypt = try Scrypt(password: Array(inputPassword.utf8), salt: Array(storedHash.salt), dkLen: 32, N: Int(pow(2, Double(memCost))), r: rounds, p: 1)
        let derivedKey = try scrypt.calculate()
        
        // Compare the hashed input password with stored hash
        return Data(derivedKey) == storedHash.hash
    }

}
