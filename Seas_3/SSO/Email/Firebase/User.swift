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

    // New initializer to create a User from UserInfo
    convenience init(from userInfo: UserInfo) {
        // Assign default values for passwordHash, salt, and iterations if not available
        let passwordHash = userInfo.passwordHash
        let salt = userInfo.salt
        let iterations = userInfo.iterations

        self.init(
            email: userInfo.email,
            userName: userInfo.userName,
            name: userInfo.name,
            passwordHash: passwordHash,
            salt: salt,
            iterations: iterations,
            isVerified: userInfo.isVerified,
            belt: userInfo.belt,
            verificationToken: userInfo.verificationToken,
            userID: UUID(uuidString: userInfo.userID) ?? UUID()
        )
    }

}
