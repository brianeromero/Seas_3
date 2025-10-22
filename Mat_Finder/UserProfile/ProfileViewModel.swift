//
//  ProfileViewModel.swift
//  Mat_Finder
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
    // MARK: - Published Properties
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

    // MARK: - Init
    @MainActor
    init(viewContext: NSManagedObjectContext, authViewModel: AuthViewModel? = nil) {
        self.viewContext = viewContext
        self.authViewModel = authViewModel ?? AuthViewModel.shared
    }

    // MARK: - Load Profile
    func loadProfile() async {
        guard let userId = authViewModel.currentUser?.userID else {
            print("⚠️ No logged-in user found in AuthViewModel")
            isProfileLoaded = true
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)

        do {
            let document = try await userRef.getDocument()
            if let data = document.data() {
                // ✅ Assign values directly to @Published properties
                self.email = data["email"] as? String ?? ""
                self.userName = data["userName"] as? String ?? ""
                self.name = data["name"] as? String ?? ""
                self.belt = data["belt"] as? String ?? ""

                // ✅ Also update currentUser so it stays in sync
                self.currentUser = User(
                    email: self.email,
                    userName: self.userName,
                    name: self.name,
                    belt: self.belt,
                    userID: userId
                )

                print("✅ Profile loaded for \(self.email)")
            } else {
                print("⚠️ No profile document found in Firestore for userID: \(userId)")
            }
        } catch {
            print("❌ Error loading profile: \(error.localizedDescription)")
        }

        // ✅ Always mark as loaded (success or fail)
        self.isProfileLoaded = true
    }

    // MARK: - Update Profile
    func updateProfile() async throws {
        guard let currentUser = authViewModel.currentUser else {
            throw NSError(domain: "User not loaded", code: 401)
        }

        if showPasswordChange && newPassword != confirmPassword {
            throw ProfileError.passwordsDoNotMatch
        }

        let userRef = Firestore.firestore().collection("users").document(currentUser.userID)
        let data: [String: Any] = [
            "email": email,
            "userName": userName,
            "name": name,
            "belt": belt
        ]

        print("📄 Updating Firestore user document for ID \(currentUser.userID)")

        do {
            try await userRef.setData(data, merge: true)
            print("✅ Profile updated successfully in Firestore")

            // ✅ Keep in-memory user in sync
            self.currentUser = User(
                email: email,
                userName: userName,
                name: name,
                belt: belt,
                userID: currentUser.userID
            )

            if showPasswordChange {
                try await authViewModel.updatePassword(newPassword)
            }
        } catch {
            print("❌ Error updating Firestore: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Validation
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
        ValidationUtility.validateField(email, type: .email)?.rawValue
    }

    func validateUserName(_ userName: String) -> String? {
        ValidationUtility.validateField(userName, type: .userName)?.rawValue
    }

    func validateName(_ name: String) -> String? {
        ValidationUtility.validateField(name, type: .name)?.rawValue
    }

    func validatePassword(_ password: String) -> String? {
        ValidationUtility.validateField(password, type: .password)?.rawValue
    }

    // MARK: - Reset Helpers
    func resetProfile() {
        print("🔄 Resetting profile fields")
        clearFields()
    }

    private func clearFields() {
        email = ""
        userName = ""
        name = ""
        belt = ""
        showPasswordChange = false
        newPassword = ""
        confirmPassword = ""
    }
}
