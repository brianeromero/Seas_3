//
//  PirateIsland+CoreDataClass.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData

@objc(PirateIsland)
public class PirateIsland: NSManagedObject {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        
        // Ensure islandID is set
        if self.islandID == nil {
            self.islandID = UUID()
        }
        
        print("Gym object created with ID: \(self.islandID?.uuidString ?? "unknown")")
    }
    
    public static func == (lhs: PirateIsland, rhs: PirateIsland) -> Bool {
        lhs.islandID == rhs.islandID &&
        lhs.islandName == rhs.islandName &&
        lhs.islandLocation == rhs.islandLocation &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude
    }
}
