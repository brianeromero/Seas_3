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
            errorMessage = "Passwords do not match"
            return
        }

        let fetchRequest = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        do {
            if let userInfo = try viewContext.fetch(fetchRequest).first {
                userInfo.email = email
                userInfo.userName = userName
                userInfo.name = name
                userInfo.belt = belt

                if showPasswordChange {
                    let hashPassword = HashPassword()
                    let hashedPassword = try hashPassword.hashPasswordScrypt(newPassword)
                    userInfo.passwordHash = hashedPassword.hash
                    try await authViewModel.updatePassword(newPassword)
                }

                try viewContext.save()
            }
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
        }

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
    }

    func validateProfile() -> Bool {
        let emailError = validateEmail(email)
        let userNameError = validateUserName(userName)
        let nameError = validateName(name)
        let passwordError = validatePassword(password)

        return [emailError, userNameError, nameError, passwordError].allSatisfy { $0 == nil }
    }

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
