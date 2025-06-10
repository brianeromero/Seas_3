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
    var passwordHash: Data // For your custom password users
    var salt: Data         // For your custom password users
    var isVerified: Bool
    var belt: String?
    var verificationToken: String?
    public var userID: String
    var iterations: Int64  // For your custom password users

    // Computed property for Identifiable
    public var id: String { userID }

    // Existing initializer for custom (e.g., CoreData) users
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

    // New initializer for FirebaseAuth.User
    public init(firebaseUser: FirebaseAuth.User, belt: String? = nil) {
        self.userID = firebaseUser.uid
        self.email = firebaseUser.email ?? "unknown@example.com" // Provide a default
        self.userName = firebaseUser.displayName ?? firebaseUser.email ?? "Unknown User"
        self.name = firebaseUser.displayName ?? "Unknown Name"
        self.isVerified = firebaseUser.isEmailVerified
        self.belt = belt // You can pass this in, or fetch from Firestore later
        // For password-related properties, set default/empty values as they don't apply to FirebaseAuth users
        self.passwordHash = Data()
        self.salt = Data()
        self.iterations = 0 // Or some other default value indicating not applicable
        self.verificationToken = nil // FirebaseAuth handles verification differently
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

    // You might also want a way to create a User from a Firestore document snapshot.
    // This assumes your Firestore document structure matches your User class properties.
    convenience init?(fromFirestoreDocument document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        guard let email = data["email"] as? String,
              let userName = data["userName"] as? String,
              let name = data["name"] as? String,
              let isVerified = data["isVerified"] as? Bool,
              let userID = data["userID"] as? String else {
            print("🚨 Error: Missing required fields in Firestore document for User.")
            return nil
        }

        // Handle optional fields and provide defaults for password-related ones if they don't exist
        let passwordHash = (data["passwordHash"] as? String)?.data(using: .utf8) ?? Data()
        let salt = (data["salt"] as? String)?.data(using: .utf8) ?? Data()
        let iterations = data["iterations"] as? Int64 ?? 0
        let belt = data["belt"] as? String
        let verificationToken = data["verificationToken"] as? String

        self.init(
            email: email,
            userName: userName,
            name: name,
            passwordHash: passwordHash,
            salt: salt,
            iterations: iterations,
            isVerified: isVerified,
            belt: belt,
            verificationToken: verificationToken,
            userID: userID
        )
    }
}
