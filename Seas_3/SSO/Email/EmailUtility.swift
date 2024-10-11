//
//  EmailUtility.swift
//  Seas_3
//
//  Created by Brian Romero on 10/9/24.
//

import Foundation
<<<<<<< HEAD
import CoreData

struct EmailUtility {
    static let persistenceController = PersistenceController.shared
    
    private static func fetchUserInfo(with predicate: NSPredicate) -> UserInfo? {
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try persistenceController.container.viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching UserInfo: \(error)")
            return nil
        }
    }

    static func fetchUserInfo(byEmail email: String) -> UserInfo? {
        fetchUserInfo(with: NSPredicate(format: "email == %@", email))
    }

    static func fetchUserInfo(byUsername username: String) -> UserInfo? {
        fetchUserInfo(with: NSPredicate(format: "userName == %@", username))
=======
import Foundation
import CoreData

// EmailUtility
func fetchUserInfo(byEmail email: String, context: NSManagedObjectContext) -> UserInfo? {
    let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "email == %@", email)
    fetchRequest.fetchLimit = 1

    do {
        let results = try context.fetch(fetchRequest)
        return results.first
    } catch {
        print("Error fetching UserInfo by email: \(error)")
        return nil
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
    }
}
