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

    @NSManaged public var userName: String?
    @NSManaged public var name: String?
    @NSManaged public var email: String?
    @NSManaged public var belt: String?
    @NSManaged public var userID: UUID?

}

extension UserInfo : Identifiable {

}
