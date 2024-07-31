//  PirateIsland+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
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
    
    @NSManaged public var coordinate: Double
    @NSManaged public var createdByUserId: String?
    @NSManaged public var createdTimestamp: Date
    @NSManaged public var gymWebsite: URL?
    @NSManaged public var islandID: UUID?
    @NSManaged public var islandLocation: String
    @NSManaged public var islandName: String
    @NSManaged public var lastModifiedByUserId: String?
    @NSManaged public var lastModifiedTimestamp: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var name: String?
    @NSManaged public var appDayOfWeeks: NSSet?
    
    // MARK: - Generated Accessors for appDayOfWeeks
    @objc(addAppDayOfWeeksObject:)
    @NSManaged public func addToAppDayOfWeeks(_ value: AppDayOfWeek)

    @objc(removeAppDayOfWeeksObject:)
    @NSManaged public func removeFromAppDayOfWeeks(_ value: AppDayOfWeek)

    @objc(addAppDayOfWeeks:)
    @NSManaged public func addToAppDayOfWeeks(_ values: NSSet)

    @objc(removeAppDayOfWeeks:)
    @NSManaged public func removeFromAppDayOfWeeks(_ values: NSSet)
    
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
        PirateIsland.dateFormatter.string(from: lastModifiedTimestamp ?? Date())
    }
    
    // Date formatter for reusability and performance
    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        return formatter
    }
    
    // MARK: - Custom Methods

    static func logFetch(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            print("Fetched \(results.count) PirateIsland objects.")
        } catch {
            print("Failed to fetch PirateIsland: \(error)")
        }
    }
}
