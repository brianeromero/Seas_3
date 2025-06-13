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
import OSLog


struct ReviewUtils {
    // This function should be async to ensure Core Data operations are performed correctly
    // on the context's queue, preventing thread violations.
    static func fetchAverageRating(for island: PirateIsland, in context: NSManagedObjectContext, callerFunction: String = #function) async -> Int16 {
        // REMOVE Thread.isMainThread and Thread.current direct checks in async functions
        // print("THREAD_LOG: ReviewUtils.fetchAverageRating - START - Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
        //os_log("Called fetchAverageRating from function: %@ (caller: %@), in file: %@, line: %d, for island: %@",
               // log: logger, type: .info, #function, callerFunction, #file, #line, island.islandName ?? "Unknown")

        // Crucial: Use context.perform to ensure Core Data operations happen on the context's queue
        return await context.perform {
            // REMOVE Thread.isMainThread and Thread.current direct checks here too
            // print("THREAD_LOG: ReviewUtils.fetchAverageRating - INSIDE perform block - Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
            
            // Fix: Explicitly specify the generic type for NSFetchRequest
            let fetchRequest: NSFetchRequest<Review> = NSFetchRequest<Review>(entityName: "Review") // Fix: Specify entityName
            fetchRequest.predicate = NSPredicate(format: "island == %@", island)

            do {
                let reviewsArray = try context.fetch(fetchRequest)
               // os_log("Fetched %d reviews for island: %@ (caller: %@)",
                   //     log: logger, type: .info, reviewsArray.count, island.islandName ?? "Unknown", callerFunction)

                guard !reviewsArray.isEmpty else {
                   // os_log("No reviews found for island: %@ (caller: %@)",
                          //  log: logger, type: .info, island.islandName ?? "Unknown", callerFunction)
                    return 0
                }

                let totalStars = reviewsArray.map { Double($0.stars) }.reduce(0, +)
                let average = totalStars / Double(reviewsArray.count)
                let roundedAverage = Int16(round(average)) // Round to nearest whole number for Int16

             //   os_log("Average rating calculated: %.2f for island: %@ (caller: %@)",
                      //  log: logger, type: .info, average, island.islandName ?? "Unknown", callerFunction)
                
                // REMOVE Thread.isMainThread and Thread.current direct checks here too
                // print("THREAD_LOG: ReviewUtils.fetchAverageRating - END perform block. Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
                return roundedAverage
            } catch {
              //  os_log("Error fetching reviews for island %@ (caller: %@): %@",
                //        log: logger, type: .error, island.islandName ?? "Unknown", callerFunction, error.localizedDescription)
                // REMOVE Thread.isMainThread and Thread.current direct checks here too
                // print("THREAD_LOG: ReviewUtils.fetchAverageRating - ERROR in perform block: \(error.localizedDescription). Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
                return 0
            }
        }
    }

    // This property seems unused or incorrectly placed. If it's a global flag
    // it should be managed carefully, perhaps as part of a ViewModel.
    // static var isReviewsFetched = false // Consider if this is truly needed here.

    // The `getReviews` function seems to be for processing already-fetched `Any?` data,
    // not for initiating a fetch. It can remain synchronous as it doesn't touch
    // the Core Data context directly.
    static func getReviews(from reviews: Any?, callerFunction: String = #function) -> [Review] {
     //   os_log("Called getReviews from function: %@ (caller: %@), in file: %@, line: %d",
         //       log: logger, type: .info, #function, callerFunction, #file, #line)

        if let orderedReviews = reviews as? NSOrderedSet {
         //   os_log("Processing reviews from NSOrderedSet, count: %d (caller: %@)",
            //        log: logger, type: .info, orderedReviews.count, callerFunction)
            return orderedReviews.compactMap { $0 as? Review }
                .sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
        }

        if let setReviews = reviews as? NSSet {
  //          os_log("Processing reviews from NSSet, count: %d (caller: %@)",
         //           log: logger, type: .info, setReviews.count, callerFunction)
            return setReviews.allObjects.compactMap { $0 as? Review }
                .sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
        }

    //    os_log("No valid review data found, returning empty array (caller: %@)",
//                log: logger, type: .info, callerFunction)
        return []
    }

    // You might also want an async version to fetch the reviews themselves
    static func fetchReviews(for island: PirateIsland, in context: NSManagedObjectContext, callerFunction: String = #function) async -> [Review] {
        // REMOVE Thread.isMainThread and Thread.current direct checks here too
        // print("THREAD_LOG: ReviewUtils.fetchReviews - START - Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
        return await context.perform {
            // REMOVE Thread.isMainThread and Thread.current direct checks here too
            // print("THREAD_LOG: ReviewUtils.fetchReviews - INSIDE perform block - Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
            do {
                // Fix: Explicitly specify the generic type for NSFetchRequest
                let fetchRequest: NSFetchRequest<Review> = NSFetchRequest<Review>(entityName: "Review") // Fix: Specify entityName
                fetchRequest.predicate = NSPredicate(format: "island == %@", island)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdTimestamp", ascending: false)]
                let reviews = try context.fetch(fetchRequest)
                // print("THREAD_LOG: ReviewUtils.fetchReviews - FETCH SUCCESS. Fetched \(reviews.count) reviews. Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
                return reviews
            } catch {
                // print("THREAD_LOG: ReviewUtils.fetchReviews - ERROR in perform block: \(error.localizedDescription). Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
                return []
            }
        }
    }
    
    // This `fetchReviews()` with no parameters is problematic.
    // If it's meant to initiate a global fetch, it must also be async
    // and handle Core Data contexts correctly. It's likely better to
    // remove this specific function or rename it to clarify its purpose
    // and ensure it uses a Core Data context.
    // For now, I'll recommend removing it as it conflicts with `fetchReviews(for:in:)`.
    /*
    static func fetchReviews() {
        os_log("Fetching reviews from the source...", log: logger, type: .info)
        os_log("Start fetching reviews from network/database...", log: logger, type: .info)
        DispatchQueue.global().async {
            sleep(2)
            os_log("Finished fetching reviews", log: logger, type: .info)
        }
    }
    */

    static func openInMaps(latitude: Double, longitude: Double, islandName: String, islandLocation: String) {
    //    os_log("Called openInMaps from function: %@, in file: %@, line: %d, for island: %@ at coordinates: %.6f, %.6f", log: logger, type: .info, #function, #file, #line, islandName, latitude, longitude)
        
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
