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
    @NSManaged public var salt: Data // Required
    @NSManaged public var iterations: Int64 // Required
    @NSManaged public var isVerified: Bool // Required
    @NSManaged public var userID: String! // Required, unique

    // Optional fields
    @NSManaged public var belt: String? // Optional
    @NSManaged public var verificationToken: String? // Optional

    // Relationship
    @NSManaged public var adSettings: AdSettings? // Relationship to AdSettings
}

extension UserInfo: Identifiable {}
