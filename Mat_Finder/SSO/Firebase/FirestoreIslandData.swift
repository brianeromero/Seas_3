//
//  FirestoreIslandData.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/30/25.
//

import Foundation

struct FirestoreIslandData {
    let id: String
    let name: String
    let location: String
    let country: String
    let createdByUserId: String
    let createdTimestamp: Date
    let lastModifiedByUserId: String
    let lastModifiedTimestamp: Date
    let latitude: Double
    let longitude: Double
    let gymWebsite: String

    init(from island: PirateIsland) {
        self.id = island.islandID?.uuidString ?? UUID().uuidString
        self.name = island.islandName ?? "Unnamed Gym"
        self.location = island.islandLocation ?? "Unknown Location"
        self.country = island.country ?? "Unknown Country"
        self.createdByUserId = island.createdByUserId ?? "Unknown"
        self.createdTimestamp = island.createdTimestamp ?? Date()
        self.lastModifiedByUserId = island.lastModifiedByUserId ?? ""
        self.lastModifiedTimestamp = island.lastModifiedTimestamp ?? Date()
        self.latitude = island.latitude
        self.longitude = island.longitude
        self.gymWebsite = island.gymWebsite?.absoluteString ?? ""
    }
}
