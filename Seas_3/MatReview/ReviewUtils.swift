//
//  ReviewUtils.swift
//  Seas_3
//
//  Created by Brian Romero on 8/26/24.
//

import Foundation
import SwiftUI
import CoreLocation

struct ReviewUtils {
    static func getReviews(from reviews: NSOrderedSet?) -> [Review] {
        guard let reviews = reviews else { return [] }
        return reviews.compactMap { $0 as? Review }
            .sorted(by: { $0.createdTimestamp > $1.createdTimestamp })
    }

    static func averageStarRating(for reviews: [Review]) -> Double {
        guard !reviews.isEmpty else {
            return 0
        }

        let totalStars = reviews.reduce(0) { $0 + Int($1.stars) }
        return Double(totalStars) / Double(reviews.count)
    }


    static func openInMaps(latitude: Double, longitude: Double, islandName: String, islandLocation: String) {
        if latitude != 0 && longitude != 0 {
            _ = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let locationString = "\(latitude),\(longitude)"
            let nameAndLocation = "\(islandName), \(islandLocation)"
            var components = URLComponents(string: "http://maps.apple.com")!
            components.queryItems = [
                URLQueryItem(name: "q", value: nameAndLocation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)),
                URLQueryItem(name: "ll", value: locationString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
            ]
            if let url = components.url {
                UIApplication.shared.open(url)
            } else {
                print("Error creating URL")
            }
        }
    }
}
