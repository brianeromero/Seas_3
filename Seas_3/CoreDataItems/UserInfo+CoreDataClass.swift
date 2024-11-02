//
//  UserInfo+CoreDataClass.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData

@objc(UserInfo)
public class UserInfo: NSManagedObject {

    // Convenience initializer to create a UserInfo object
    convenience init(context: NSManagedObjectContext) {
        self.init(entity: UserInfo.entity(), insertInto: context)
        userID = UUID().uuidString // Assign a unique String for userID
    }
}
