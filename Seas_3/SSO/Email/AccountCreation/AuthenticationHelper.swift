//
//  AuthenticationHelper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/28/24.
//

import Foundation
import SwiftUI
import CoreData

struct HashedPassword {
    var hash: Data
    var salt: Data
    var iterations: Int
}


class AuthenticationHelper {
    static func verifyUserPassword(inputPassword: String, storedHash: HashedPassword) throws -> Bool {
        let hashPassword = HashPassword()
        
        // Directly passing Data (salt and hash) to verifyPasswordScrypt
        return try hashPassword.verifyPasswordScrypt(inputPassword, againstHash: storedHash)
    }
    
    static func fetchStoredUserHash(identifier: String) throws -> HashedPassword {
        let context = PersistenceController.shared.viewContext  // Use shared viewContext

        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "email == %@", identifier),
            NSPredicate(format: "userName == %@", identifier)
        ])
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = predicate

        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                throw HashError.invalidInput
            }

            // Convert base64 string to Data
            guard let saltData = Data(base64Encoded: user.salt) else {
                throw HashError.invalidInput
            }
            guard let hashData = Data(base64Encoded: user.passwordHash) else {
                throw HashError.invalidInput
            }

            // Return the HashedPassword struct with decoded data
            return HashedPassword(hash: hashData, salt: saltData, iterations: Int(user.iterations))
        } catch {
            throw HashError.coreDataError(error)
        }
    }

    // New method for verifying admin credentials
    static func verifyAdminCredentials(username: String, password: String) async -> Bool {
        // Example logic: Replace with your actual admin credential verification
        return username == "Admin" && password == "Password"
    }
}
