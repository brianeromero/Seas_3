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

public class User: Codable, Identifiable {
    var email: String
    var userName: String
    var name: String
    var passwordHash: Data
    var salt: Data
    var isVerified: Bool
    var belt: String?
    var verificationToken: String?
    public var userID: String
    var iterations: Int64

    // Computed property for Identifiable
    public var id: String { userID }

    init(email: String,
         userName: String,
         name: String,
         passwordHash: Data,
         salt: Data,
         iterations: Int64,
         isVerified: Bool = false,
         belt: String? = nil,
         verificationToken: String? = nil,
         userID: String = UUID().uuidString) {
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

    // Convenience initializer from UserInfo (if needed)
    convenience init(from userInfo: UserInfo) {
        let passwordHash = Data(base64Encoded: userInfo.passwordHash) ?? Data()
        let salt = Data(base64Encoded: userInfo.salt) ?? Data()
        
        self.init(
            email: userInfo.email,
            userName: userInfo.userName,
            name: userInfo.name,
            passwordHash: passwordHash,
            salt: salt,
            iterations: userInfo.iterations,
            isVerified: userInfo.isVerified,
            belt: userInfo.belt,
            verificationToken: userInfo.verificationToken,
            userID: userInfo.userID
        )
    }
}
