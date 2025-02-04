//
//  UserInfo+CoreDataClass.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//
//

import Foundation
import CoreData
import FirebaseFirestore

@objc(UserInfo)
public class UserInfo: NSManagedObject {

    // Convenience initializer to create a UserInfo object in Core Data
    convenience init(context: NSManagedObjectContext) {
        self.init(entity: UserInfo.entity(), insertInto: context)
        userID = UUID().uuidString // Assign a unique String for userID
    }
    
    // New initializer to create a UserInfo object from a Firestore document
    convenience init(fromFirestoreDocument document: QueryDocumentSnapshot, context: NSManagedObjectContext) {
        self.init(context: context)
        
        // Map Firestore fields to Core Data attributes
        self.userID = document.documentID // Assuming Firestore documentID is the userID
        self.email = document.data()["email"] as? String ?? ""
        self.userName = document.data()["username"] as? String ?? ""
        self.passwordHash = document.data()["passwordHash"] as? Data ?? Data()
        self.salt = document.data()["salt"] as? Data ?? Data()
        self.iterations = document.data()["iterations"] as? Int64 ?? 1000
        self.isVerified = document.data()["isVerified"] as? Bool ?? false
        self.isBanned = document.data()["isBanned"] as? Bool ?? false
        self.belt = document.data()["belt"] as? String
        self.verificationToken = document.data()["verificationToken"] as? String
    }
}
