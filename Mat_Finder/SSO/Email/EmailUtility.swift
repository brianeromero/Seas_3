//
//  EmailUtility.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/9/24.
//

import Foundation
import CoreData

struct EmailUtility {
    static let persistenceController = PersistenceController.shared

    // MARK: - Fetch by email
    static func fetchUserInfo(byEmail email: String) async -> UserInfo? {
        let context = persistenceController.container.viewContext
        return await context.perform {
            let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "email == %@", email)
            fetchRequest.fetchLimit = 1

            do {
                let results = try context.fetch(fetchRequest)
                return results.first
            } catch {
                print("Error fetching UserInfo by email: \(error)")
                return nil
            }
        }
    }

    // MARK: - Fetch by username
    static func fetchUserInfo(byUserName userName: String) async -> UserInfo? {
        let context = persistenceController.container.viewContext
        return await context.perform {
            let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "userName == %@", userName)
            fetchRequest.fetchLimit = 1

            do {
                let results = try context.fetch(fetchRequest)
                return results.first
            } catch {
                print("Error fetching UserInfo by username: \(error)")
                return nil
            }
        }
    }
}
