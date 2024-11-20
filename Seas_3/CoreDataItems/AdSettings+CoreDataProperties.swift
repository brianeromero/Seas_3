//
//  AdSettings+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 11/19/24.
//
//

import Foundation
import CoreData

extension AdSettings {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AdSettings> {
        return NSFetchRequest<AdSettings>(entityName: "AdSettings")
    }

    @NSManaged public var idfa: String? // IDFA attribute
    @NSManaged public var enabled: Bool // Enabled attribute
    @NSManaged public var user: UserInfo? // Relationship to UserInfo
}


extension AdSettings : Identifiable {

}
