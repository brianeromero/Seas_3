//
//  ProfileViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 11/4/24.
//

import Foundation
import SwiftUI
import CoreData
import Firebase


class ProfileViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var userName: String = ""
    @Published var name: String = ""
    @Published var belt: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var showPasswordChange: Bool = false
    @Published var password: String = ""
    private var viewContext: NSManagedObjectContext
    private var authViewModel: AuthViewModel

    init(viewContext: NSManagedObjectContext, authViewModel: AuthViewModel = .shared) {
        self.viewContext = viewContext
        self.authViewModel = authViewModel
        loadProfile()
    }

    func loadProfile() {
        let fetchRequest = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        do {
            if let userInfo = try viewContext.fetch(fetchRequest).first {
                email = userInfo.email
                userName = userInfo.userName
                name = userInfo.name
                belt = userInfo.belt ?? ""
            } else {
                print("No user profile found.")
            }
        } catch {
            print("Error loading profile: \(error.localizedDescription)")
        }
    }

    func updateProfile() async {
        guard !showPasswordChange || newPassword == confirmPassword else {
            print("Passwords do not match")
            return
        }

        let fetchRequest = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        do {
            if let userInfo = try viewContext.fetch(fetchRequest).first {
                userInfo.email = email
                userInfo.userName = userName
                userInfo.name = name
                userInfo.belt = belt

                // Update password if changing
                if showPasswordChange {
                    let hashPassword = HashPassword()
                    // Hash the password
                    let hashedPassword = try hashPassword.hashPasswordScrypt(newPassword)
                    
                    // Store the hashed password
                    userInfo.passwordHash = hashedPassword.hash

                    // Optionally: Update password in Firebase as well
                    try await authViewModel.updatePassword(newPassword)
                }

                try viewContext.save()
            }
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
        }

        // Update Firestore document with user info
        do {
            try await updateFirestoreDocument()
        } catch {
            print("Error updating Firestore document: \(error.localizedDescription)")
        }
    }

    private func updateFirestoreDocument() async throws {
        guard let userId = authViewModel.currentUser?.userID else {
            throw NSError(domain: "User not authenticated", code: 401, userInfo: nil)
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        try await userRef.setData([
            "email": email,
            "userName": userName,
            "name": name,
            "belt": belt
        ], merge: true)
        print("User data successfully saved to Firestore.")
    }

    func validateProfile() -> Bool {
        let emailError = ValidationUtility.validateEmail(email)
        let userNameError = ValidationUtility.validateUserName(userName)
        let nameError = ValidationUtility.validateName(name)

        let isValid = [emailError, userNameError, nameError].allSatisfy { $0 == nil }

        if !isValid {
            if let emailError = emailError {
                print("Email error: \(emailError.rawValue)")
            }
            if let userNameError = userNameError {
                print("Username error: \(userNameError.rawValue)")
            }
            if let nameError = nameError {
                print("Name error: \(nameError.rawValue)")
            }
        }

        return isValid
    }
}

extension Data {
    static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        if status != errSecSuccess {
            fatalError("Unable to generate random bytes")
        }
        return Data(bytes)
    }
}
