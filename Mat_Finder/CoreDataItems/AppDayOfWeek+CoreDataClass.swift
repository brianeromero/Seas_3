//
//  AppDayOfWeek+CoreDataClass.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData

@objc(AppDayOfWeek)
public class AppDayOfWeek: NSManagedObject {

    public static func == (lhs: AppDayOfWeek, rhs: AppDayOfWeek) -> Bool {
        lhs.objectID == rhs.objectID
    }
}

