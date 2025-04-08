//
//  MatTime+CoreDataProperties.swift
//  Seas_3
//
//  Created by Brian Romero on 7/15/24.
//
//


import Foundation
import CoreData

extension MatTime {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MatTime> {
        return NSFetchRequest<MatTime>(entityName: "MatTime")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var time: String?
    @NSManaged public var gi: Bool
    @NSManaged public var noGi: Bool
    @NSManaged public var openMat: Bool
    @NSManaged public var restrictions: Bool
    @NSManaged public var restrictionDescription: String?
    @NSManaged public var goodForBeginners: Bool
    @NSManaged public var kids: Bool
    @NSManaged public var createdTimestamp: Date?
    
    @NSManaged public var appDayOfWeek: AppDayOfWeek?

}

extension MatTime: Identifiable {}

extension MatTime {
    func toFirestoreData() -> [String: Any] {
        return [
            "time": self.time ?? "",
            "type": self.type ?? "",
            "gi": self.gi,
            "noGi": self.noGi,
            "openMat": self.openMat,
            "restrictions": self.restrictions,
            "restrictionDescription": self.restrictionDescription ?? "",
            "goodForBeginners": self.goodForBeginners,
            "kids": self.kids,
            "createdTimestamp": self.createdTimestamp ?? Date(),
        ]
    }
}
