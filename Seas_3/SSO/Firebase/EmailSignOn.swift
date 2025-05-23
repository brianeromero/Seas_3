//
//  EmailSignOn.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import CryptoSwift


class EmailSignOn {
    func exampleUsage() {
        // Create an instance of HashPassword
        let hashPassword = HashPassword()
        
        // Storing hashed password
        let userPassword = "mysecretpassword"
        do {
            let hashedPassword = try hashPassword.hashPasswordScrypt(userPassword)
            
            // Use hashedPassword properties for the User object
            _ = User(email: "user@example.com",
                     userName: "username",  // Updated here
                     name: "John Doe",
                     passwordHash: hashedPassword.hash,  // Use the Data directly here
                     salt: hashedPassword.salt,  // Use the salt Data directly here
                     iterations: Int64(hashedPassword.iterations),  // Store the iterations
                     isVerified: false,
                     belt: nil,
                     verificationToken: nil,
                     userID: UUID().uuidString) // Convert UUID to String here
            
            // Verify password
            if try hashPassword.verifyPasswordScrypt(userPassword, againstHash: hashedPassword) {
                print("Password is valid")
            } else {
                print("Password is invalid")
            }
        } catch {
            print("Error during password processing: \(error)")
        }
    }
}
