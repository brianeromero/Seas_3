//
//  MatTime+CoreDataClass.swift
//  Mat_Finder
//

import Foundation
import CoreData

@objc(MatTime)
public class MatTime: NSManagedObject {

    // MARK: - Lifecycle

    override public func awakeFromInsert() {
        super.awakeFromInsert()

        // Ensure stable unique identifier
        if id == nil {
            id = UUID()
        }

        // Default values
        womensOnly = false
    }

    // MARK: - Equality

    /// Two MatTime objects are equal if they share the same stable id.
    public static func == (lhs: MatTime, rhs: MatTime) -> Bool {
        lhs.id == rhs.id
    }
}
