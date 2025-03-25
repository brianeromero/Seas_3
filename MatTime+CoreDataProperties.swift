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
    // MARK: - Firestore Data Conversion
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [:]
        
        // Add properties to the dictionary
        data["time"] = time
        data["description"] = restrictionDescription
        
        return data
    }
}
