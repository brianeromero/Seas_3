//
// PirateIsland+CoreDataProperties.swift
// Mat_Finder
//
// Created by Brian Romero on 6/24/24.
//

import Foundation
import CoreData

extension PirateIsland: Identifiable {}

extension PirateIsland {

    // MARK: - Review Relationship Helpers
    
    public var reviewsArray: [Review] {
        return (reviews)?.array as? [Review] ?? []
    }

    func addReview(_ review: Review) {
        let mutableSet = mutableOrderedSetValue(forKey: "reviews")
        mutableSet.add(review)
    }

    func removeReview(_ review: Review) {
        let mutableSet = mutableOrderedSetValue(forKey: "reviews")
        mutableSet.remove(review)
    }

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PirateIsland> {
        NSFetchRequest<PirateIsland>(entityName: "PirateIsland")
    }

    // MARK: - Attributes
    
    @NSManaged public var createdByUserId: String?
    @NSManaged public var createdTimestamp: Date?
    @NSManaged public var gymWebsite: URL?
    @NSManaged public var islandID: String?
    @NSManaged public var islandLocation: String?
    @NSManaged public var country: String?
    @NSManaged public var islandName: String?
    @NSManaged public var lastModifiedByUserId: String?
    @NSManaged public var lastModifiedTimestamp: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double

    // 🔥 NEW FIELDS
    @NSManaged public var hasDropInFee: Int16
    @NSManaged public var dropInFeeAmount: Double
    @NSManaged public var dropInFeeNote: String?
    
    
    var dropInFeeStatus: HasDropInFee {
        get {
            HasDropInFee(rawValue: hasDropInFee) ?? .notConfirmed
        }
        set {
            hasDropInFee = newValue.rawValue
        }
    }

    // MARK: - Relationships
    
    @NSManaged public var appDayOfWeeks: NSSet?
    @NSManaged public var reviews: NSOrderedSet?

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
        AppDateFormatter.full.string(from: lastModifiedTimestamp ?? Date())
    }

    public var formattedCreatedTimestamp: String {
        AppDateFormatter.mediumDateTime.string(from: createdTimestamp ?? Date())
    }

    public var safeIslandLocation: String {
        islandLocation ?? "Unknown Location"
    }

    public var safeIslandName: String {
        islandName ?? "Unnamed Gym"
    }

    public var safeCountry: String {
        country ?? "Unknown Country"
    }

    public var daysOfWeekArray: [AppDayOfWeek] {
        let set = appDayOfWeeks as? Set<AppDayOfWeek> ?? []
        return set.sorted { $0.day < $1.day }
    }

    // MARK: - Drop-In Display Logic
    public var dropInDisplayText: String {

        switch dropInFeeStatus {

        case .notConfirmed:
            return "Needs Confirmation"

        case .noDropInFee:
            return "No Drop-In Fee"

        case .hasFee:

            if dropInFeeAmount > 0 {

                return NumberFormatter.localizedString(
                    from: NSNumber(value: dropInFeeAmount),
                    number: .currency
                )
            }

            if let note = dropInFeeNote,
               !note.trimmingCharacters(in: .whitespaces).isEmpty {
                return note
            }

            return "Drop-In Fee"
        }
    }
    // MARK: - Logging
    
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

    // MARK: - Firestore Data Conversion
    
    func toFirestoreData() -> [String: Any]? {

        var data: [String: Any] = [:]

        data["islandID"] = islandID
        data["islandName"] = islandName
        data["islandLocation"] = islandLocation
        data["latitude"] = latitude
        data["longitude"] = longitude
        data["country"] = country
        data["createdByUserId"] = createdByUserId
        data["createdTimestamp"] = createdTimestamp
        data["lastModifiedByUserId"] = lastModifiedByUserId
        data["lastModifiedTimestamp"] = lastModifiedTimestamp

        // 🔥 NEW FIELDS
        data["hasDropInFee"] = dropInFeeStatus.rawValue
        data["dropInFeeAmount"] = dropInFeeAmount
        data["dropInFeeNote"] = dropInFeeNote

        return data
    }
}

extension PirateIsland {

    func configure(_ data: [String: Any]) {

        if let islandIDString = data["islandID"] as? String {
            self.islandID = islandIDString
        } else {
            self.islandID = UUID().uuidString
        }

        self.islandName = data["islandName"] as? String
        self.islandLocation = data["islandLocation"] as? String
        self.country = data["country"] as? String

        // 🔥 NEW FIELDS
        let raw = Int16(data["hasDropInFee"] as? Int ?? -1)
        self.dropInFeeStatus = HasDropInFee(rawValue: raw) ?? .notConfirmed
        self.dropInFeeAmount = data["dropInFeeAmount"] as? Double ?? 0
        self.dropInFeeNote = data["dropInFeeNote"] as? String

        // ⭐ AUTO-FIX LEGACY RECORDS (2800 gyms)
        if dropInFeeStatus == .noDropInFee && dropInFeeAmount == 0 && dropInFeeNote == nil {
            dropInFeeStatus = .notConfirmed
        }

        if data["days"] is [String] {
            // TODO: create or fetch AppDayOfWeek objects and associate
        }
    }
    
}
