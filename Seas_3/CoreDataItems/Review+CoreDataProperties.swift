//
//  Review+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 8/23/24.
//
//

import Foundation
import CoreData

extension Review {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Review> {
        return NSFetchRequest<Review>(entityName: "Review")
    }

    @NSManaged public var stars: Int16
    @NSManaged public var review: String
    @NSManaged public var createdTimestamp: Date
    @NSManaged public var averageStar: Int16


    // MARK: - Relationships
    @NSManaged public var island: PirateIsland?

    
}
