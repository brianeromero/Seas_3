//
//  EmailUtility.swift
//  Seas_3
//
//  Created by Brian Romero on 10/9/24.
//

import Foundation
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
    }
}
