//
//  MatTime+CoreDataClass.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/15/24.
//
//

import Foundation
import CoreData

@objc(MatTime)
public class MatTime: NSManagedObject {

    public static func == (lhs: MatTime, rhs: MatTime) -> Bool {
        lhs.time == rhs.time &&
        lhs.type == rhs.type
    }
}
