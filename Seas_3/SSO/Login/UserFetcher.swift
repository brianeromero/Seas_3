//
//  UserFetcher.swift
//  Seas_3
//
//  Created by Brian Romero on 2/3/25.
//
import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreData  

class UserFetcher {
    private let db = Firestore.firestore()

    // Unified fetch function
    func fetchUser(usernameOrEmail: String, context: NSManagedObjectContext?) async throws -> UserInfo {
        if let context = context {
            // Try fetching from Core Data if context is provided
            if let user = try? fetchUserFromCoreData(usernameOrEmail, context: context) {
                return user // Return if found in Core Data
            }
        }
        
        // If not found in Core Data (or no context), fall back to Firestore
        return try await fetchUserFromFirestore(usernameOrEmail)
    }


    // Fetch from Core Data
    private func fetchUserFromCoreData(_ usernameOrEmail: String, context: NSManagedObjectContext) throws -> UserInfo {
        let request = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        request.predicate = NSPredicate(format: "userName == %@ OR email == %@", usernameOrEmail, usernameOrEmail)

        let results = try context.fetch(request)
        if results.isEmpty {
            print("No user found in Core Data for \(usernameOrEmail)")
            throw UserFetchError.userNotFound
        }
        guard let user = results.first else { throw UserFetchError.userNotFound }
        return user
    }

    // Fetch from Firestore
    private func fetchUserFromFirestore(_ usernameOrEmail: String) async throws -> UserInfo {
        let usersRef = db.collection("users")

        let querySnapshot = try await usersRef
            .whereField("email", isEqualTo: usernameOrEmail)
            .getDocuments()

        if let document = querySnapshot.documents.first {
            print("Found user in Firestore with email: \(usernameOrEmail)")
            return UserInfo(fromFirestoreDocument: document, context: PersistenceController.shared.viewContext)
        }

        let usernameQuerySnapshot = try await usersRef
            .whereField("username", isEqualTo: usernameOrEmail)
            .getDocuments()

        if let document = usernameQuerySnapshot.documents.first {
            print("Found user in Firestore with username: \(usernameOrEmail)")
            return UserInfo(fromFirestoreDocument: document, context: PersistenceController.shared.viewContext)
        }

        print("No user found in Firestore for \(usernameOrEmail)")
        throw UserFetchError.userNotFound
    }
}
