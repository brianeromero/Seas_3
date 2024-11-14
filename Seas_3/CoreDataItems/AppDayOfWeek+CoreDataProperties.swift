//
//  AppDayOfWeek+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData

extension AppDayOfWeek {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppDayOfWeek> {
        return NSFetchRequest<AppDayOfWeek>(entityName: "AppDayOfWeek")
    }

    @NSManaged public var day: String // Changed from Optional to non-Optional
    @NSManaged public var pIsland: PirateIsland?
    @NSManaged public var name: String?
    @NSManaged public var appDayOfWeekID: String?
    @NSManaged public var matTimes: NSSet?
    @NSManaged public var createdTimestamp: Date?
    @NSManaged public var id: UUID?


    
    // Generated Accessors
    @objc(addMatTimesObject:)
    @NSManaged public func addToMatTimes(_ value: MatTime)

    @objc(removeMatTimesObject:)
    @NSManaged public func removeFromMatTimes(_ value: MatTime)

    @objc(addMatTimes:)
    @NSManaged public func addToMatTimes(_ values: NSSet)

    @objc(removeMatTimes:)
    @NSManaged public func removeFromMatTimes(_ values: NSSet)
    
}

extension AppDayOfWeek : Identifiable {
}
