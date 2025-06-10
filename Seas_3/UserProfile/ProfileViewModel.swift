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

@MainActor // Add this attribute to your ProfileViewModel class
public class ProfileViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var userName: String = ""
    @Published var name: String = ""
    @Published var belt: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var showPasswordChange: Bool = false
    @Published var password: String = ""
    @Published var isSignInEnabled: Bool = true
    @Published var errorMessage: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var isProfileLoaded: Bool = false
    @Published var isVerified: Bool = false

    var isProfileValid: Bool {
        !name.isEmpty && !userName.isEmpty
    }

    private var viewContext: NSManagedObjectContext
    private var authViewModel: AuthViewModel

    init(viewContext: NSManagedObjectContext, authViewModel: AuthViewModel = .shared) {
        self.viewContext = viewContext
        self.authViewModel = authViewModel
    }

    func loadProfile() async {
        print("📥 loadProfile() called")
        print("Current Firebase user: \(Auth.auth().currentUser?.uid ?? "nil")")

        guard let userId = authViewModel.currentUser?.userID else {
            print("❌ No user ID found")
            isProfileLoaded = true // No need for await MainActor.run, class is already MainActor isolated
            return
        }

        print("🔎 Loading Firestore profile for user ID: \(userId)")
        let userRef = Firestore.firestore().collection("users").document(userId)

        do {
            let document = try await userRef.getDocument()
            if document.exists {
                let data = document.data()
                print("✅ Profile document found. Updating fields...")
                email = data?["email"] as? String ?? ""
                userName = data?["userName"] as? String ?? ""
                name = data?["name"] as? String ?? ""
                belt = data?["belt"] as? String ?? ""
                isProfileLoaded = true
            } else {
                print("⚠️ No profile document found")
                isProfileLoaded = true
            }
        } catch {
            print("❌ Error loading profile: \(error.localizedDescription)")
            isProfileLoaded = true
        }
    }

    func updateProfile() async throws {
        print("✏️ updateProfile() called")

        guard let userId = authViewModel.currentUser?.userID else {
            print("❌ User ID not found in AuthViewModel")
            throw NSError(domain: "User not authenticated", code: 401, userInfo: nil)
        }

        print("🔄 Attempting to update profile for user ID: \(userId)")
        print("📧 Email: \(email), 👤 Username: \(userName), 🧑 Name: \(name), 🥋 Belt: \(belt)")

        if showPasswordChange {
            print("🔐 Password change requested")
            if newPassword != confirmPassword {
                print("❌ Passwords do not match: '\(newPassword)' vs '\(confirmPassword)'")
                throw ProfileError.passwordsDoNotMatch
            }
        }

        do {
            try await updateFirestoreDocument()
            print("✅ Firestore document updated successfully")

            if showPasswordChange {
                print("🔄 Attempting to update password...")
                try await authViewModel.updatePassword(newPassword)
                print("✅ Password updated successfully")
            }
        } catch {
            print("❌ Failed to update profile: \(error.localizedDescription)")
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
