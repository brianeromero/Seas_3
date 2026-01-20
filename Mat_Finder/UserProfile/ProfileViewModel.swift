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
public final class ProfileViewModel: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - Profile Fields
    @Published var email = ""
    @Published var userName = ""
    @Published var name = ""
    @Published var belt = ""

    // MARK: - Password Editing
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var showPasswordChange = false

    // MARK: - State
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var currentUser: User?

    // MARK: - Load Profile (AUTH TRIGGERS THIS)
    func loadProfile(for userID: String) async {
        loadState = .loading

        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(userID)
                .getDocument()

            guard let data = doc.data() else {
                loadState = .failed("Profile not found")
                return
            }

            let user = User(
                email: data["email"] as? String ?? "",
                userName: data["userName"] as? String ?? "",
                name: data["name"] as? String ?? "",
                belt: data["belt"] as? String ?? "",
                userID: userID
            )

            self.currentUser = user
            self.email = user.email
            self.userName = user.userName
            self.name = user.name
            self.belt = user.belt ?? ""

            loadState = .loaded

        } catch {
            loadState = .failed("Failed to load profile")
        }
    }

    // MARK: - Update Profile
    func updateProfile(using authViewModel: AuthViewModel) async throws {
        guard let user = currentUser else {
            throw NSError(domain: "Profile not loaded", code: 400)
        }

        if showPasswordChange && newPassword != confirmPassword {
            throw ProfileError.passwordsDoNotMatch
        }

        let ref = Firestore.firestore().collection("users").document(user.userID)

        let data: [String: Any] = [
            "email": email,
            "userName": userName,
            "name": name,
            "belt": belt
        ]

        try await ref.setData(data, merge: true)

        self.currentUser = User(
            email: email,
            userName: userName,
            name: name,
            belt: belt,
            userID: user.userID
        )

        if showPasswordChange {
            try await authViewModel.updatePassword(newPassword)
        }
    }

    // MARK: - Validation
    var isProfileValid: Bool {
        !email.isEmpty && !userName.isEmpty && !name.isEmpty
    }

    // MARK: - Reset
    func reset() {
        loadState = .idle
        currentUser = nil
        email = ""
        userName = ""
        name = ""
        belt = ""
        newPassword = ""
        confirmPassword = ""
        showPasswordChange = false
    }
}
