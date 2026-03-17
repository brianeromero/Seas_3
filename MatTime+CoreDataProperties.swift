//
//  MatTime+CoreDataProperties.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/15/24.
//
//


import Foundation
import CoreData
import FirebaseFirestore

extension MatTime {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MatTime> {
        return NSFetchRequest<MatTime>(entityName: "MatTime")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var discipline: String?   // ✅ ADD THIS

    @NSManaged public var time: String?

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

        let id = self.id ?? UUID()
        self.id = id

        var data: [String: Any] = [
            "id": id.uuidString,
            "time": self.time ?? "",
            "discipline": self.discipline ?? Discipline.bjjGi.rawValue,
            "kids": self.kids,
            "goodForBeginners": self.goodForBeginners,
            "womensOnly": self.womensOnly,
            "restrictions": self.restrictions,
            "restrictionDescription": self.restrictionDescription ?? "",
            "createdTimestamp": self.createdTimestamp ?? Date()
        ]

        if let type = self.type, !type.isEmpty {
            data["type"] = type
        }

        if let style = self.style, !style.isEmpty {
            data["style"] = style
        }

        if let custom = self.customStyle, !custom.isEmpty {
            data["customStyle"] = custom
        }

        if let dayID = self.appDayOfWeekID {
            data["appDayOfWeekID"] = dayID
        }

        return data
    }
}


extension MatTime {
    // Configure from a Firestore-style dictionary
    func configure(data: [String: Any]) {

        self.time = data["time"] as? String

        // Normalize discipline
        if let raw = data["discipline"] as? String,
           Discipline(rawValue: raw) != nil {
            self.discipline = raw
        } else {
            self.discipline = Discipline.bjjGi.rawValue
        }

        self.type = data["type"] as? String

        // Normalize style
        if let raw = data["style"] as? String,
           Style(rawValue: raw) != nil {
            self.style = raw
        } else {
            self.style = nil
        }

        // Only allow customStyle if style == .custom
        if self.style == Style.custom.rawValue {
            self.customStyle = data["customStyle"] as? String
        } else {
            self.customStyle = nil
        }

        self.restrictions = data["restrictions"] as? Bool ?? false
        self.restrictionDescription = data["restrictionDescription"] as? String ?? ""

        self.goodForBeginners = data["goodForBeginners"] as? Bool ?? false
        self.kids = data["kids"] as? Bool ?? false
        self.womensOnly = data["womensOnly"] as? Bool ?? false

        if let idString = data["id"] as? String {
            self.id = UUID(uuidString: idString)
        }

        if let timestamp = data["createdTimestamp"] as? Timestamp {
            self.createdTimestamp = timestamp.dateValue()
        } else if let date = data["createdTimestamp"] as? Date {
            self.createdTimestamp = date
        } else {
            self.createdTimestamp = Date()
        }
    }
    
    // Direct in-app configuration
    func configure(
        time: String?,
        type: String?,
        style: String?,
        customStyle: String?,
        discipline: String?,
        restrictions: Bool,
        restrictionDescription: String?,
        goodForBeginners: Bool,
        kids: Bool,
        womensOnly: Bool
    ) {

        self.time = time
        self.type = type
        self.discipline = discipline

        self.customStyle = customStyle
        self.style = style

        self.restrictions = restrictions
        self.restrictionDescription = restrictionDescription
        self.goodForBeginners = goodForBeginners
        self.kids = kids
        self.womensOnly = womensOnly
    }
}

