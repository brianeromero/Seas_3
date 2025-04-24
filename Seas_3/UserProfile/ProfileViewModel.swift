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

enum ProfileError: Error, LocalizedError {
    case passwordsDoNotMatch

    var errorDescription: String? {
        switch self {
        case .passwordsDoNotMatch:
            return "Passwords do not match."
        }
    }
}




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
    
    private var viewContext: NSManagedObjectContext
    private var authViewModel: AuthViewModel
    
    init(viewContext: NSManagedObjectContext, authViewModel: AuthViewModel = .shared) {
        self.viewContext = viewContext
        self.authViewModel = authViewModel
    }
    
    // Load the profile information
    func loadProfile() async {
        guard let userId = authViewModel.currentUser?.userID else {
            print("No user ID found")
            await MainActor.run {
                isProfileLoaded = true
            }
            return
        }

        print("Current user ID:", userId)

        let userRef = Firestore.firestore().collection("users").document(userId)
        do {
            let document = try await userRef.getDocument()
            if document.exists {
                let data = document.data()
                print("Profile data loaded from Firestore: \(String(describing: data))")
                await MainActor.run {
                    email = data?["email"] as? String ?? ""
                    userName = data?["userName"] as? String ?? ""
                    name = data?["name"] as? String ?? ""
                    belt = data?["belt"] as? String ?? ""
                    print("Loaded profile - Email: \(email), Username: \(userName), Name: \(name), Belt: \(belt)")
                    isProfileLoaded = true
                }
            } else {
                print("No user profile found in Firestore")
                await MainActor.run {
                    isProfileLoaded = true
                }
            }
        } catch {
            print("Error loading profile: \(error.localizedDescription)")
            await MainActor.run {
                isProfileLoaded = true
            }
        }
    }

    // Update profile information
    func updateProfile() async throws {
        guard (authViewModel.currentUser?.userID) != nil else {
            throw NSError(domain: "User not authenticated", code: 401, userInfo: nil)
        }

        // If the guard passes, proceed with updating the profile
        print("Updating profile - Email: \(email), Username: \(userName), Name: \(name), Belt: \(belt)")

        try await updateFirestoreDocument()

        if showPasswordChange {
            try await authViewModel.updatePassword(newPassword)
        }
    }



    // Helper to update Firestore document
    private func updateFirestoreDocument() async throws {
        guard let userId = authViewModel.currentUser?.userID else {
            throw NSError(domain: "User not authenticated", code: 401, userInfo: nil)
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        print("Saving profile data to Firestore: Email: \(email), Username: \(userName), Name: \(name), Belt: \(belt)")

        do {
            try await userRef.setData([
                "email": email,
                "userName": userName,
                "name": name,
                "belt": belt
            ], merge: true)
            print("Firestore update succeeded")
        } catch {
            // Catch Firestore errors here and log them
            print("Error saving profile data to Firestore: \(error.localizedDescription)")
            throw error // Re-throw the error to be handled by the calling function
        }
    }


    // Validate the profile fields
    func validateProfile() -> Bool {
        let emailError = validateEmail(email)
        let userNameError = validateUserName(userName)
        let nameError = validateName(name)
        let passwordError = showPasswordChange ? validatePassword(newPassword) : nil

        return [emailError, userNameError, nameError, passwordError].allSatisfy { $0 == nil }
    }


    // Validate individual fields
    func validateEmail(_ email: String) -> String? {
        return ValidationUtility.validateField(email, type: .email)?.rawValue
    }
    
    func validateUserName(_ userName: String) -> String? {
        return ValidationUtility.validateField(userName, type: .userName)?.rawValue
    }

    func validateName(_ name: String) -> String? {
        return ValidationUtility.validateField(name, type: .name)?.rawValue
    }

    func validatePassword(_ password: String) -> String? {
        return ValidationUtility.validateField(password, type: .password)?.rawValue
    }

    // Reset profile to default values
    func resetProfile() {
        email = ""
        userName = ""
        name = ""
        belt = ""
        showPasswordChange = false
        newPassword = ""
        confirmPassword = ""
    }
}
