//
//  PirateIsland+CoreDataClass.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/24/24.
//

import Foundation
import CoreData

@objc(PirateIsland)
public class PirateIsland: NSManagedObject {

    // MARK: - Lifecycle
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()

        if islandID == nil {
            islandID = UUID().uuidString
        }

        hasDropInFee = HasDropInFee.notConfirmed.rawValue
        dropInFeeAmount = 0
        dropInFeeNote = nil

        print("Gym object created with ID: \(islandID ?? "unknown")")
    }

    // MARK: - Equality
    
    /// Two PirateIsland objects are equal if they share the same stable islandID.
    public static func == (lhs: PirateIsland, rhs: PirateIsland) -> Bool {
        return lhs.islandID == rhs.islandID
    }
}
