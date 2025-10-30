//
//  ReviewUtils.swift
//  Mat_Finder
//
//  Created by Brian Romero on 8/26/24.
//
import Foundation
import SwiftUI
import CoreData
import CoreLocation
import os.log
import os
import OSLog


struct ReviewUtils {
 
    static func fetchAverageRating(for island: PirateIsland, in context: NSManagedObjectContext, callerFunction: String = #function) async -> Int16 {
        let islandID = island.objectID // Capture the objectID outside the closure

        return await context.perform {
            // Rehydrate the island inside the context's queue
            guard let islandInContext = try? context.existingObject(with: islandID) as? PirateIsland else {
                os_log("❌ Failed to rehydrate PirateIsland (caller: %@)", log: logger, type: .error, callerFunction)
                return 0
            }

            let fetchRequest: NSFetchRequest<Review> = NSFetchRequest<Review>(entityName: "Review")
            fetchRequest.predicate = NSPredicate(format: "island == %@", islandInContext)

            do {
                let reviewsArray = try context.fetch(fetchRequest)
                guard !reviewsArray.isEmpty else { return 0 }

                let totalStars = reviewsArray.reduce(0.0) { $0 + Double($1.stars) }
                return Int16(round(totalStars / Double(reviewsArray.count)))
            } catch {
                os_log("❌ Error fetching reviews (caller: %@): %@", log: logger, type: .error, callerFunction, error.localizedDescription)
                return 0
            }
        }
    }

    
    
    static func fetchAverageRating(
        forObjectID islandObjectID: NSManagedObjectID,
        in context: NSManagedObjectContext,
        callerFunction: String = #function
    ) async -> Int16 {
        return await context.perform {
            guard let island = try? context.existingObject(with: islandObjectID) as? PirateIsland else {
                os_log("❌ Failed to rehydrate PirateIsland (caller: %@)", log: logger, type: .error, callerFunction)
                return 0
            }

            let fetchRequest: NSFetchRequest<Review> = NSFetchRequest(entityName: "Review")
            fetchRequest.predicate = NSPredicate(format: "island == %@", island)

            do {
                let reviews = try context.fetch(fetchRequest)
                guard !reviews.isEmpty else { return 0 }

                let totalStars = reviews.reduce(0.0) { $0 + Double($1.stars) }
                return Int16(round(totalStars / Double(reviews.count)))
            } catch {
                os_log("❌ Error fetching average rating (caller: %@): %@", log: logger, type: .error, callerFunction, error.localizedDescription)
                return 0
            }
        }
    }

     
    static func getReviews(from reviews: Any?, callerFunction: String = #function) -> [Review] {
 
        if let orderedReviews = reviews as? NSOrderedSet {
             return orderedReviews.compactMap { $0 as? Review }
                .sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
        }

        if let setReviews = reviews as? NSSet {
             return setReviews.allObjects.compactMap { $0 as? Review }
                .sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
        }

         return []
    }

     static func fetchReviews(for island: PirateIsland, in context: NSManagedObjectContext, callerFunction: String = #function) async -> [Review] {
        let islandID = island.objectID

        return await context.perform {
            guard let islandInContext = try? context.existingObject(with: islandID) as? PirateIsland else {
                os_log("❌ Failed to rehydrate PirateIsland (caller: %@)", log: logger, type: .error, callerFunction)
                return []
            }

            let fetchRequest: NSFetchRequest<Review> = NSFetchRequest(entityName: "Review")
            fetchRequest.predicate = NSPredicate(format: "island == %@", islandInContext)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]

            do {
                let reviews = try context.fetch(fetchRequest)
                return reviews
            } catch {
                os_log("❌ Error fetching reviews (caller: %@): %@", log: logger, type: .error, callerFunction, error.localizedDescription)
                return []
            }
        }
    }

     

    static func openInMaps(latitude: Double, longitude: Double, islandName: String, islandLocation: String) {
 
        guard latitude != 0, longitude != 0 else {
            os_log("Invalid coordinates, not opening maps", log: logger, type: .error)
            return
        }

        let locationString = "\(latitude),\(longitude)"
        let nameAndLocation = "\(islandName), \(islandLocation)"
        var components = URLComponents(string: "http://maps.apple.com")!
        components.queryItems = [
            URLQueryItem(name: "q", value: nameAndLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)),
            URLQueryItem(name: "ll", value: locationString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        ]

        if let url = components.url {
            os_log("Opening maps with URL: %@", log: logger, type: .info, url.absoluteString)
            UIApplication.shared.open(url)
        } else {
            os_log("Error creating Apple Maps URL", log: logger, type: .error)
        }
    }
}
