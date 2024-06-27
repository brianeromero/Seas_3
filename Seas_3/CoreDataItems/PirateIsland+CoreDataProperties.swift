//
//  PirateIsland+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData
import CoreLocation
import MapKit

extension PirateIsland {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PirateIsland> {
        return NSFetchRequest<PirateIsland>(entityName: "PirateIsland")
    }

    @NSManaged public var createdTimestamp: Date?
    @NSManaged public var islandID: UUID?
    @NSManaged public var coordinate: Double
    @NSManaged public var gymWebsite: URL?
    @NSManaged public var islandLocation: String?
    @NSManaged public var islandName: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var createdByUserId: String?
    @NSManaged public var lastModifiedByUserId: String?
    @NSManaged public var lastModifiedTimestamp: Date?

    // Updated relationship to AppDayOfWeek
    @NSManaged public var appDayOfWeeks: NSSet?
}

// MARK: Generated accessors for appDayOfWeeks
extension PirateIsland {

    @objc(addAppDayOfWeeksObject:)
    @NSManaged public func addToAppDayOfWeeks(_ value: AppDayOfWeek)

    @objc(removeAppDayOfWeeksObject:)
    @NSManaged public func removeFromAppDayOfWeeks(_ value: AppDayOfWeek)

    @objc(addAppDayOfWeeks:)
    @NSManaged public func addToAppDayOfWeeks(_ values: NSSet)

    @objc(removeAppDayOfWeeks:)
    @NSManaged public func removeFromAppDayOfWeeks(_ values: NSSet)
    
    
    // Function to fetch PirateIslands near a given location
    static func fetchIslandsNear(location: CLLocationCoordinate2D, within distance: CLLocationDistance, in context: NSManagedObjectContext) -> [PirateIsland] {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        
        let latitude = location.latitude
        let longitude = location.longitude
        
        // Calculate bounding box for the search region
        let region = MKCoordinateRegion(center: location, latitudinalMeters: distance, longitudinalMeters: distance)
        let north = latitude + region.span.latitudeDelta / 2.0
        let south = latitude - region.span.latitudeDelta / 2.0
        let east = longitude + region.span.longitudeDelta / 2.0
        let west = longitude - region.span.longitudeDelta / 2.0
        
        fetchRequest.predicate = NSPredicate(format: "latitude <= %@ AND latitude >= %@ AND longitude <= %@ AND longitude >= %@", argumentArray: [north, south, east, west])
        
        do {
            let results = try context.fetch(fetchRequest)
            print("Fetched \(results.count) PirateIsland objects.")
            return results
        } catch {
            print("Error fetching PirateIslands near location: \(error)")
            return []
        }
    }
    
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

extension PirateIsland: Identifiable {}
