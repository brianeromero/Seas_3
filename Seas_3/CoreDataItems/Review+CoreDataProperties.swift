//
//  Review+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 8/23/24.
//
//


import Foundation
import CoreData
import os

extension Review: Identifiable {
    @nonobjc public class func fetchRequest(context: NSManagedObjectContext, selectedIsland: PirateIsland?) -> NSFetchRequest<Review> {
        // Log function call and call stack
        let callStack = Thread.callStackSymbols.joined(separator: "\n")
        os_log("Called fetchRequest for Review from function: %@\nCall Stack: %@", log: logger, type: .info, #function, callStack)

        let fetchRequest = NSFetchRequest<Review>(entityName: "Review")

        // Log the island associated with this fetch request
        if let island = selectedIsland {
            os_log("Fetching reviews for Island: %@", log: logger, type: .info, island.islandName ?? "Unknown Island")
            fetchRequest.predicate = NSPredicate(format: "island == %@", island)  // ✅ Ensure filtering by island
        } else {
            os_log("No island selected. Fetching all reviews.", log: logger, type: .info)
        }

        // Sort by newest reviews
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]

        // Log the number of results for the fetch request (before executing)
        do {
            let resultCount = try context.count(for: fetchRequest)
            os_log("Review fetch request will return %d results", log: logger, type: .info, resultCount)
        } catch {
            os_log("Error counting results for fetch request: %@", log: logger, type: .error, error.localizedDescription)
        }

        return fetchRequest
    }

    @NSManaged public var stars: Int16
    @NSManaged public var review: String
    @NSManaged public var createdTimestamp: Date
    @NSManaged public var averageStar: Int16
    @NSManaged public var reviewID: UUID

    // MARK: - Relationships
    @NSManaged public var island: PirateIsland?

    // Identifiable conformance
    public var id: NSManagedObjectID {
        return self.objectID
    }
}
