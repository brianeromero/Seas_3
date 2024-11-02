//
//  User.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//
import Foundation
import CryptoSwift
import FirebaseFirestore
import FirebaseAuth

class User: Codable, Identifiable {
    var email: String
    var userName: String
    var name: String
    var passwordHash: Data
    var salt: Data
    var isVerified: Bool
    var belt: String?
    var verificationToken: String?
    var userID: UUID
    var iterations: Int64

    // Existing initializer
    init(email: String,
         userName: String,
         name: String,
         passwordHash: Data,
         salt: Data,
         iterations: Int64,
         isVerified: Bool = false,
         belt: String? = nil,
         verificationToken: String? = nil,
         userID: UUID = UUID()) {
        self.email = email
        self.userName = userName
        self.name = name
        self.passwordHash = passwordHash
        self.salt = salt
        self.iterations = iterations
        self.isVerified = isVerified
        self.belt = belt
        self.verificationToken = verificationToken
        self.userID = userID
    }

    // New initializer to create a User from FirebaseAuth.User
    convenience init(from firebaseUser: FirebaseAuth.User, userName: String, name: String) {
        // Assign default values for passwordHash, salt, and iterations
        self.init(
            email: firebaseUser.email ?? "",
            userName: userName,
            name: name,
            passwordHash: Data(), // Default value or you can handle this differently
            salt: Data(), // Default value or you can handle this differently
            iterations: 0, // Default value or you can handle this differently
            isVerified: false // Set default verification status
        )
    }
}
