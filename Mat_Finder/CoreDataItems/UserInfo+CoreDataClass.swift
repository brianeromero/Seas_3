//
//  UserInfo+CoreDataClass.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData
import FirebaseFirestore

@objc(UserInfo)
public class UserInfo: NSManagedObject {

    // MARK: - Basic Init
    convenience init(context: NSManagedObjectContext) {
        guard let entity = NSEntityDescription.entity(forEntityName: "UserInfo", in: context) else {
            preconditionFailure("⚠️ UserInfo entity not found in Core Data model!")
        }
        self.init(entity: entity, insertInto: context)
        self.userID = UUID().uuidString
    }

    // MARK: - Init from Firestore QueryDocumentSnapshot
    convenience init(fromFirestoreDocument document: QueryDocumentSnapshot, context: NSManagedObjectContext) {
        self.init(context: context)
        mapFirestoreData(document.data(), documentID: document.documentID)
    }

    // MARK: - Init from Firestore DocumentSnapshot (single doc fetch)
    convenience init(fromDocument document: DocumentSnapshot, context: NSManagedObjectContext) {
        self.init(context: context)
        mapFirestoreData(document.data() ?? [:], documentID: document.documentID)
    }

    // MARK: - Common Mapping Function
    private func mapFirestoreData(_ data: [String: Any], documentID: String) {
        self.userID = documentID
        self.email = data["email"] as? String ?? ""
        self.userName = data["username"] as? String ?? ""
        self.name = data["name"] as? String ?? ""
        self.passwordHash = data["passwordHash"] as? Data ?? Data()
        self.salt = data["salt"] as? Data ?? Data()
        self.iterations = data["iterations"] as? Int64 ?? 1000
        self.isVerified = data["isVerified"] as? Bool ?? false
        self.isBanned = data["isBanned"] as? Bool ?? false
        self.belt = data["belt"] as? String
        self.verificationToken = data["verificationToken"] as? String
    }
}
