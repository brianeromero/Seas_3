//
//  UserInfo+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//

import Foundation
import CoreData

extension UserInfo {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserInfo> {
        return NSFetchRequest<UserInfo>(entityName: "UserInfo")
    }

    // Required fields
    @NSManaged public var userName: String // Required
    @NSManaged public var name: String // Required
    @NSManaged public var email: String // Required
    @NSManaged public var passwordHash: Data // Required
    @NSManaged public var isVerified: Bool // Required
    
    // Optional fields
    @NSManaged public var belt: String? // Optional (if applicable)
    @NSManaged public var userID: UUID? // Optional (if applicable)
    @NSManaged public var verificationToken: String? // Optional (if applicable)
}

extension UserInfo: Identifiable {}
