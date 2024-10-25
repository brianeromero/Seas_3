//
//  EmailSignOn.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation

class EmailSignOn {
    func exampleUsage() {
        // Storing hashed password
        let userPassword = "mysecretpassword"
        do {
            let hashedPassword = try hashPasswordPbkdf(userPassword)
            // Use hashedPassword properties for the User object
            _ = User(email: "user@example.com",
                            username: "username",
                            name: "John Doe",
                            passwordHash: hashedPassword.hash,
                            salt: hashedPassword.salt,
                            iterations: Int64(hashedPassword.iterations),
                            isVerified: false,
                            belt: nil,
                            verificationToken: nil,
                            userID: UUID())
            
            // Verify password
            if try verifyPasswordPbkdf(userPassword, againstHash: hashedPassword) {
                print("Password is valid")
            } else {
                print("Password is invalid")
            }
        } catch {
            print("Error during password processing: \(error)")
        }
    }
}
