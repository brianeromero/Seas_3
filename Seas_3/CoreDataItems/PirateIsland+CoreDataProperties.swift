//
// PirateIsland+CoreDataProperties.swift
// Seas_3
//
// Created by Brian Romero on 6/24/24.
//

import Foundation
import CoreData

// Ensure PirateIsland conforms to Identifiable
extension PirateIsland: Identifiable {}

extension PirateIsland {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PirateIsland> {
        return NSFetchRequest<PirateIsland>(entityName: "PirateIsland")
    }

    // MARK: - Attributes

    @NSManaged public var createdByUserId: String?
    @NSManaged public var createdTimestamp: Date?
    @NSManaged public var gymWebsite: URL?
    @NSManaged public var islandID: UUID?
    @NSManaged public var islandLocation: String?
    @NSManaged public var country: String?  // NEW ATTRIBUTE
    @NSManaged public var islandName: String?
    @NSManaged public var lastModifiedByUserId: String?
    @NSManaged public var lastModifiedTimestamp: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double

    // MARK: - Relationships

    @NSManaged public var appDayOfWeeks: NSSet?
    @NSManaged public var reviews: NSOrderedSet?  // Make sure this is NSOrderedSet for ordered relationships

    // MARK: - Computed Properties

    public var formattedCoordinates: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }

    public var formattedLatitude: String {
        String(format: "%.6f", latitude)
    }

    public var formattedLongitude: String {
        String(format: "%.6f", longitude)
    }

    public var formattedTimestamp: String {
        DateFormat.full.string(from: lastModifiedTimestamp ?? Date())
    }

    // Ensure you have appropriate default values or handling for optional properties
    public var safeIslandLocation: String {
        islandLocation ?? "Unknown Location"
    }

    public var safeIslandName: String {
        islandName ?? "Unnamed Gym"
    }

    // NEW COMPUTED PROPERTY
    public var safeCountry: String {
        country ?? "Unknown Country"
    }

    // Convert the NSSet of appDayOfWeeks to an array of AppDayOfWeek
    public var daysOfWeekArray: [AppDayOfWeek] {
        let set = appDayOfWeeks as? Set<AppDayOfWeek> ?? []
        return set.sorted { $0.day < $1.day }
    }

    // MARK: - Custom Methods

    static func logFetch(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            print("Fetched \(results.count) Gym objects.")
        } catch {
            print("Failed to fetch Gym: \(error)")
        }
    }

    // MARK: - Generated Accessors for appDayOfWeeks
    @objc(addAppDayOfWeeksObject:)
    @NSManaged public func addToAppDayOfWeeks(_ value: AppDayOfWeek)

    @objc(removeAppDayOfWeeksObject:)
    @NSManaged public func removeFromAppDayOfWeeks(_ value: AppDayOfWeek)

    @objc(addAppDayOfWeeks:)
    @NSManaged public func addToAppDayOfWeeks(_ values: NSSet)

    @objc(removeAppDayOfWeeks:)
    @NSManaged public func removeFromAppDayOfWeeks(_ values: NSSet)

    // MARK: - Generated Accessors for reviews
    @objc(insertObject:inReviewsAtIndex:)
    @NSManaged public func insertIntoReviews(_ value: Review, at idx: Int)

    @objc(removeObjectFromReviewsAtIndex:)
    @NSManaged public func removeFromReviews(at idx: Int)

    @objc(insertReviews:atIndexes:)
    @NSManaged public func insertIntoReviews(_ values: [Review], at indexes: NSIndexSet)

    @objc(removeReviewsAtIndexes:)
    @NSManaged public func removeFromReviews(at indexes: NSIndexSet)

    @objc(replaceObjectInReviewsAtIndex:withObject:)
    @NSManaged public func replaceReviews(at idx: Int, with value: Review)

    @objc(replaceReviewsAtIndexes:withReviews:)
    @NSManaged public func replaceReviews(at indexes: NSIndexSet, with values: [Review])
}
