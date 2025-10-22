//
//  HashPassword.swift
//  Mat_Finder
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

public protocol PasswordHasher {
    func verifyPassword(_ password: String, against hashedPassword: HashedPassword) throws -> Bool
    func verifyPasswordScrypt(_ password: String, againstHash hashedPassword: HashedPassword) throws -> Bool
    var base64SaltSeparator: String { get }
}


internal class HashPassword: PasswordHasher {  // Keep this internal
    // Firebase Authentication Scrypt configuration
    let algorithm = "SCRYPT"
    let base64SignerKey = "Kt5JkNrRAeub1x2rDuCq1BYKmVIOfTTeRyPQAItJzO4gfCfg9JRzWTkC1wKGIoEUZ9N2CZY6DtXwK9s81ZpdvA=="
    public let base64SaltSeparator = "Bw==" // Public for protocol conformance
    let rounds = 8
    let memCost = 14

    // Convert base64 signer key to Data
    let signerKeyData: Data

    public init() {
        guard let data = Data(base64Encoded: base64SignerKey) else {
            fatalError("Failed to convert base64 signer key to Data")
        }
        signerKeyData = data
    }

    // Hash password using Scrypt
    public func hashPasswordScrypt(_ password: String) throws -> HashedPassword {
        let salt = try generateSalt(ofLength: 16)
        let scrypt = try Scrypt(password: Array(password.utf8), salt: Array(salt), dkLen: 32, N: Int(pow(2, Double(memCost))), r: rounds, p: 1)
        let hashedPassword = try scrypt.calculate()
        return HashedPassword(hash: Data(hashedPassword), salt: salt, iterations: memCost)
    }

    // Verify password using SCRYPT (for protocol)
    public func verifyPassword(_ password: String, against hashedPassword: HashedPassword) throws -> Bool {
        try verifyPasswordScrypt(password, againstHash: hashedPassword)
    }

    public func verifyPasswordScrypt(_ inputPassword: String, againstHash storedHash: HashedPassword) throws -> Bool {
        let scrypt = try Scrypt(password: Array(inputPassword.utf8), salt: Array(storedHash.salt), dkLen: 32, N: Int(pow(2, Double(memCost))), r: rounds, p: 1)
        let derivedKey = try scrypt.calculate()
        return Data(derivedKey) == storedHash.hash
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
}
