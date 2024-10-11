//
//  UserInfo+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData

extension UserInfo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserInfo> {
        return NSFetchRequest<UserInfo>(entityName: "UserInfo")
    }

    // Make these fields non-optional
    @NSManaged public var userName: String // Required
    @NSManaged public var name: String // Required
    @NSManaged public var email: String // Required
    @NSManaged public var belt: String? // Optional (if applicable)
    @NSManaged public var userID: UUID? // Optional (if applicable)
    @NSManaged public var passwordHash: Data // Required
<<<<<<< HEAD
    @NSManaged public var isVerified: Bool // Required
    @NSManaged public var verificationToken: String? // Optional (if applicable)
=======
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9

}

extension UserInfo: Identifiable {}
