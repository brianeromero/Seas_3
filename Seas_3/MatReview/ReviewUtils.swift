//
//  ReviewUtils.swift
//  Seas_3
//
//  Created by Brian Romero on 8/26/24.
//
import Foundation
import SwiftUI
import CoreData
import CoreLocation
import os.log

import os

struct ReviewUtils {
    static func fetchAverageRating(for island: PirateIsland, in context: NSManagedObjectContext) -> Double {
        os_log("Called fetchAverageRating from function: %@, in file: %@, line: %d, for island: %@", log: logger, type: .info, #function, #file, #line, island.islandName ?? "Unknown")
        
        let fetchRequest = Review.fetchRequest(context: context, selectedIsland: island)

        do {
            let reviewsArray = try context.fetch(fetchRequest)
            os_log("Fetched %d reviews for island: %@", log: logger, type: .info, reviewsArray.count, island.islandName ?? "Unknown")

            guard !reviewsArray.isEmpty else {
                os_log("No reviews found for island: %@", log: logger, type: .info, island.islandName ?? "Unknown")
                return 0.0
            }

            let averageRating = reviewsArray.map { Double($0.stars) }.reduce(0, +) / Double(reviewsArray.count)
            os_log("Average rating calculated: %.2f for island: %@", log: logger, type: .info, averageRating, island.islandName ?? "Unknown")
            return averageRating
        } catch {
            os_log("Error fetching reviews for island %@: %@", log: logger, type: .error, island.islandName ?? "Unknown", error.localizedDescription)
            return 0.0
        }
    }

    static var isReviewsFetched = false

    static func getReviews(from reviews: Any?) -> [Review] {
        os_log("Called getReviews from function: %@, in file: %@, line: %d", log: logger, type: .info, #function, #file, #line)
        
        // Check if reviews are already fetched
        os_log("isReviewsFetched is currently: %@", log: logger, type: .info, String(isReviewsFetched))
        
        if !isReviewsFetched {
            os_log("Reviews not fetched yet, fetching reviews...", log: logger, type: .info)
            
            // Fetch reviews logic here
            fetchReviews()
            
            // After fetching, set the flag to true
            isReviewsFetched = true
            os_log("isReviewsFetched set to true", log: logger, type: .info)
        } else {
            os_log("Reviews already fetched, skipping fetch", log: logger, type: .info)
        }
        
        // Check if reviews is of type NSOrderedSet
        if let orderedReviews = reviews as? NSOrderedSet {
            os_log("Processing reviews from NSOrderedSet, count: %d", log: logger, type: .info, orderedReviews.count)
            return orderedReviews.compactMap { $0 as? Review }
                .sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
        }
        
        // Check if reviews is of type NSSet
        if let setReviews = reviews as? NSSet {
            os_log("Processing reviews from NSSet, count: %d", log: logger, type: .info, setReviews.count)
            return setReviews.allObjects.compactMap { $0 as? Review }
                .sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
        }
        
        // If no valid review data is found
        os_log("No valid review data found, returning empty array", log: logger, type: .info)
        return []
    }

    static func fetchReviews() {
        os_log("Fetching reviews from the source...", log: logger, type: .info)
        
        // Here you can simulate or implement the actual fetch logic
        // e.g., network call, CoreData fetch, etc.
        
        // Example for logging fetch start
        os_log("Start fetching reviews from network/database...", log: logger, type: .info)
        
        // Simulate some fetch delay (optional for testing)
        DispatchQueue.global().async {
            // Simulate fetching process
            sleep(2) // Simulate delay for async fetch

            // Once fetching is complete
            os_log("Finished fetching reviews", log: logger, type: .info)
            
            // Now you could set `isReviewsFetched = true` here if needed.
        }
    }

    static func averageStarRating(for reviews: [Review]) -> Double {
        os_log("Called averageStarRating from function: %@, in file: %@, line: %d, for %d reviews", log: logger, type: .info, #function, #file, #line, reviews.count)
        
        guard !reviews.isEmpty else {
            os_log("No reviews provided for calculating average rating", log: logger, type: .info)
            return 0
        }
        
        let totalStars = reviews.reduce(0) { $0 + Int($1.stars) }
        let averageRating = Double(totalStars) / Double(reviews.count)
        os_log("Calculated average star rating: %.2f", log: logger, type: .info, averageRating)
        return averageRating
    }

    static func openInMaps(latitude: Double, longitude: Double, islandName: String, islandLocation: String) {
        os_log("Called openInMaps from function: %@, in file: %@, line: %d, for island: %@ at coordinates: %.6f, %.6f", log: logger, type: .info, #function, #file, #line, islandName, latitude, longitude)
        
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
