//
//  AuthenticationHelper.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/28/24.
//

import Foundation
import SwiftUI
import CoreData

class AuthenticationHelper {

    @MainActor
    static func fetchStoredUserHash(identifier: String) throws -> HashedPassword {
        let context = PersistenceController.shared.viewContext  // Now allowed

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

    static func verifyUserPassword(inputPassword: String, storedHash: HashedPassword) throws -> Bool {
        let hashPassword = HashPassword()
        return try hashPassword.verifyPasswordScrypt(inputPassword, againstHash: storedHash)
    }

    @MainActor
    static func verifyAdminCredentials(username: String, password: String) async -> Bool {
        let validAdmins: [String: String] = [
            "Admin": "Password",
            "brian.counterpointux@gmail.com": "Abcd12345!!!"
        ]
        return validAdmins[username] == password
    }
}
