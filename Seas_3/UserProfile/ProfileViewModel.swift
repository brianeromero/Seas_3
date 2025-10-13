//
//  ProfileViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 11/4/24.
//

import Foundation
import SwiftUI
import CoreData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

enum ProfileError: Error, LocalizedError {
    case passwordsDoNotMatch

    var errorDescription: String? {
        switch self {
        case .passwordsDoNotMatch:
            return "Passwords do not match."
        }
    }
}

@MainActor
public class ProfileViewModel: ObservableObject {
    @Published var email = ""
    @Published var userName = ""
    @Published var name = ""
    @Published var belt = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var showPasswordChange = false
    @Published var password = ""
    @Published var isSignInEnabled = true
    @Published var errorMessage = ""
    @Published var isLoggedIn = false
    @Published var isProfileLoaded = false
    @Published var isVerified = false
    @Published var currentUser: User?

    var isProfileValid: Bool {
        !name.isEmpty && !userName.isEmpty
    }

    private var viewContext: NSManagedObjectContext
    private var authViewModel: AuthViewModel

    @MainActor
    init(viewContext: NSManagedObjectContext, authViewModel: AuthViewModel? = nil) {
        self.viewContext = viewContext
        // Assign the shared instance inside the initializer body
        self.authViewModel = authViewModel ?? AuthViewModel.shared
    }


    func loadProfile() async {
        guard let userId = authViewModel.currentUser?.userID else {
            isProfileLoaded = true
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)

        do {
            let document = try await userRef.getDocument()
            if document.exists {
                let context = PersistenceController.shared.container.viewContext
                let userInfo = UserInfo(fromDocument: document, context: context)
                self.currentUser = User(from: userInfo) // map to your User struct/class

                // ✅ Copy values into editable properties
                self.email = self.currentUser?.email ?? ""
                self.userName = self.currentUser?.userName ?? ""
                self.name = self.currentUser?.name ?? ""
                self.belt = self.currentUser?.belt ?? ""

                print("✅ Profile loaded for \(userInfo.email)")
            } else {
                print("⚠️ No profile document found in Firestore for userID: \(userId)")
            }
        } catch {
            print("❌ Error loading profile: \(error)")
        }

        isProfileLoaded = true
    }




    func updateProfile() async throws {
        guard let currentUser = currentUser else {
            throw NSError(domain: "User not loaded", code: 401)
        }

        if showPasswordChange {
            if newPassword != confirmPassword {
                throw ProfileError.passwordsDoNotMatch
            }
        }

        let userRef = Firestore.firestore().collection("users").document(currentUser.userID)
        let data: [String: Any] = [
            "email": currentUser.email,
            "userName": currentUser.userName,
            "name": currentUser.name,
            "belt": currentUser.belt ?? ""
        ]

        do {
            try await userRef.setData(data, merge: true)
            if showPasswordChange {
                try await authViewModel.updatePassword(newPassword)
            }
        } catch {
            throw error
        }
    }


    private func updateFirestoreDocument() async throws {
        print("📤 updateFirestoreDocument() called")

        guard let userId = authViewModel.currentUser?.userID else {
            throw NSError(domain: "User not authenticated", code: 401, userInfo: nil)
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        let data: [String: Any] = [
            "email": email,
            "userName": userName,
            "name": name,
            "belt": belt
        ]

        print("📄 Uploading data to Firestore: \(data)")

        do {
            try await userRef.setData(data, merge: true)
            print("✅ Firestore setData successful for user ID: \(userId)")
        } catch let error as NSError {
            print("❌ Firebase error [domain: \(error.domain), code: \(error.code)]: \(error.localizedDescription)")
            throw error
        }
    }


    func validateProfile() -> Bool {
        print("🔍 Running profile validation...")
        
        let emailError = validateEmail(email)
        let userNameError = validateUserName(userName)
        let nameError = validateName(name)
        let passwordError = showPasswordChange ? validatePassword(newPassword) : nil

        let validations: [(String, String?)] = [
            ("Email", emailError),
            ("Username", userNameError),
            ("Name", nameError),
            ("Password", passwordError)
        ]

        for (field, error) in validations {
            if let error = error {
                print("❌ Validation failed for \(field): \(error)")
            } else {
                print("✅ Validation passed for \(field)")
            }
        }

        return validations.allSatisfy { $0.1 == nil }
    }

    func validateEmail(_ email: String) -> String? {
        print("🔍 Validating email: \(email)")
        return ValidationUtility.validateField(email, type: .email)?.rawValue
    }

    func validateUserName(_ userName: String) -> String? {
        print("🔍 Validating username: \(userName)")
        return ValidationUtility.validateField(userName, type: .userName)?.rawValue
    }

    func validateName(_ name: String) -> String? {
        print("🔍 Validating name: \(name)")
        return ValidationUtility.validateField(name, type: .name)?.rawValue
    }

    func validatePassword(_ password: String) -> String? {
        print("🔍 Validating password: \(password)")
        return ValidationUtility.validateField(password, type: .password)?.rawValue
    }

    func resetProfile() {
        print("🔄 Resetting profile fields")
        email = ""
        userName = ""
        name = ""
        belt = ""
        showPasswordChange = false
        newPassword = ""
        confirmPassword = ""
    }
}
