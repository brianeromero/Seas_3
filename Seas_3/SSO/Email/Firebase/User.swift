//
//  User.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import CryptoSwift
import FirebaseFirestore

class User: Codable, Identifiable {
    var email: String
    var username: String
    var name: String
    var passwordHash: Data
    var salt: Data
    var isVerified: Bool
    var belt: String?
    var verificationToken: String?
    var userID: UUID
    var iterations: Int64


    init(email: String,
          username: String,
          name: String,
          passwordHash: Data,
          salt: Data,
          iterations: Int64,
          isVerified: Bool = false,
          belt: String? = nil,
          verificationToken: String? = nil,
          userID: UUID = UUID()) {
        self.email = email
        self.username = username
        self.name = name
        self.passwordHash = passwordHash
        self.salt = salt
        self.iterations = iterations
        self.isVerified = isVerified
        self.belt = belt
        self.verificationToken = verificationToken
        self.userID = userID
    }
}
