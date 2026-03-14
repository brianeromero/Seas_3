//
//  MatTime+CoreDataProperties.swift
//  Mat_Finder
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
    @NSManaged public var discipline: String?   // ✅ ADD THIS

    @NSManaged public var time: String?
    @NSManaged public var gi: Bool
    @NSManaged public var noGi: Bool
    @NSManaged public var openMat: Bool
    @NSManaged public var restrictions: Bool
    @NSManaged public var restrictionDescription: String?
    @NSManaged public var goodForBeginners: Bool
    @NSManaged public var kids: Bool
    @NSManaged public var womensOnly: Bool   // ✅ ADD THIS
    @NSManaged public var createdTimestamp: Date?
    
    // ⭐ ADD IT RIGHT HERE
    @NSManaged public var appDayOfWeekID: String?
    @NSManaged public var appDayOfWeek: AppDayOfWeek?

    
    @NSManaged public var customStyle: String?
    @NSManaged public var style: String?
}

extension MatTime: Identifiable {}

extension MatTime {
    func toFirestoreData() -> [String: Any] {

        var data: [String: Any] = [
            "time": self.time ?? "",
            "type": self.style ?? self.type ?? "",
            "discipline": self.discipline ?? "bjj",
            "gi": self.gi,
            "noGi": self.noGi,
            "openMat": self.openMat,
            "restrictions": self.restrictions,
            "restrictionDescription": self.restrictionDescription ?? "",
            "goodForBeginners": self.goodForBeginners,
            "kids": self.kids,
            "womensOnly": self.womensOnly,
            "createdTimestamp": self.createdTimestamp ?? Date()
        ]

        if let custom = self.customStyle, !custom.isEmpty {
            data["customStyle"] = custom
        }

        if let style = self.style, !style.isEmpty {
            data["style"] = style
        }

        return data
    }
}


extension MatTime {
    // Configure from a Firestore-style dictionary
    func configure(data: [String: Any]) {

        self.time = data["time"] as? String
        self.type = data["type"] as? String
        self.discipline = (data["discipline"] as? String ?? "bjj").lowercased()
        
        self.customStyle = data["customStyle"] as? String
        self.style = data["style"] as? String

        self.gi = data["gi"] as? Bool ?? false
        self.noGi = data["noGi"] as? Bool ?? false
        self.openMat = data["openMat"] as? Bool ?? false
        self.restrictions = data["restrictions"] as? Bool ?? false
        self.restrictionDescription = data["restrictionDescription"] as? String ?? ""
        self.goodForBeginners = data["goodForBeginners"] as? Bool ?? false
        self.kids = data["kids"] as? Bool ?? false
        self.womensOnly = data["womensOnly"] as? Bool ?? false
        if let idString = data["id"] as? String {
            self.id = UUID(uuidString: idString)
        }
        self.createdTimestamp = data["createdTimestamp"] as? Date ?? Date()
    }

    // Direct in-app configuration
    func configure(
        time: String?,
        type: String?,
        style: String?,
        customStyle: String?,
        discipline: String?,
        gi: Bool,
        noGi: Bool,
        openMat: Bool,
        restrictions: Bool,
        restrictionDescription: String?,
        goodForBeginners: Bool,
        kids: Bool,
        womensOnly: Bool
    ) {
        self.time = time
        self.type = type
        self.discipline = discipline?.lowercased()
        
        self.customStyle = customStyle
        self.style = style

        self.gi = gi
        self.noGi = noGi
        self.openMat = openMat
        self.restrictions = restrictions
        self.restrictionDescription = restrictionDescription
        self.goodForBeginners = goodForBeginners
        self.kids = kids
        self.womensOnly = womensOnly
    }
}
