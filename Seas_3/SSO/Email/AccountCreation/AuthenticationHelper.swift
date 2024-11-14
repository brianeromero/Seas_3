//
//  AuthenticationHelper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/28/24.
//

import Foundation
import SwiftUI
import CoreData


class AuthenticationHelper {
    static func verifyUserPassword(inputPassword: String, storedHash: HashedPassword) throws -> Bool {
        return try verifyPasswordPbkdf(inputPassword, againstHash: storedHash)
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
            return HashedPassword(salt: user.salt, iterations: Int(user.iterations), hash: user.passwordHash)
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

