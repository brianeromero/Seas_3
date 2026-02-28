//
//  AppDayOfWeek+CoreDataProperties.swift
//  Mat_Finder
//

import Foundation
import CoreData

extension AppDayOfWeek {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppDayOfWeek> {
        NSFetchRequest<AppDayOfWeek>(entityName: "AppDayOfWeek")
    }

    // =====================================================
    // Existing fields
    // =====================================================

    @NSManaged public var day: String

    @NSManaged public var name: String?

    @NSManaged public var appDayOfWeekID: String?

    @NSManaged public var createdTimestamp: Date?

    @NSManaged public var id: UUID?


    // =====================================================
    // ⭐ CRITICAL ADD — FOREIGN KEY
    // =====================================================

    /// Permanent foreign key to PirateIsland
    /// Enables automatic relationship repair
    @NSManaged public var pirateIslandID: String?


    // =====================================================
    // Relationships
    // =====================================================

    @NSManaged public var pIsland: PirateIsland?

    @NSManaged public var matTimes: NSSet?


    // =====================================================
    // Generated Accessors
    // =====================================================

    @objc(addMatTimesObject:)
    @NSManaged public func addToMatTimes(_ value: MatTime)

    @objc(removeMatTimesObject:)
    @NSManaged public func removeFromMatTimes(_ value: MatTime)

    @objc(addMatTimes:)
    @NSManaged public func addToMatTimes(_ values: NSSet)

    @objc(removeMatTimes:)
    @NSManaged public func removeFromMatTimes(_ values: NSSet)
}

extension AppDayOfWeek: Identifiable {}
