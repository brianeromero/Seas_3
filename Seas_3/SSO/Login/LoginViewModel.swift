//
//  LoginViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 11/13/24.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreData
import SwiftUI

class LoginViewModel: ObservableObject {
    @Published var usernameOrEmail: String = ""
    @Published var password: String = ""
    @Published var isSignInEnabled: Bool = false
    @Published var errorMessage: String = ""
    @Published var isLoggedIn: Bool = false
    @Published var showMainContent: Bool = false
    
    // Remove @Environment(\.managedObjectContext) from here
    // You can pass viewContext explicitly in methods that need it
    
    // Method to validate email format
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // Sign In Method
    func signIn(viewContext: NSManagedObjectContext) async {
        guard !usernameOrEmail.isEmpty && !password.isEmpty else {
            self.errorMessage = "Please enter both username and password."
            return
        }

        do {
            var emailToUse: String? = nil
            
            // Step 1: Check Core Data for user
            if validateEmail(usernameOrEmail) {
                if let user = try? fetchUser(usernameOrEmail, viewContext: viewContext) {
                    emailToUse = user.email
                }
            }

            // Step 2: If not found in Core Data, check Firestore
            if emailToUse == nil {
                emailToUse = try await fetchFirestoreUserEmail(for: usernameOrEmail)
            }

            guard let email = emailToUse else {
                self.errorMessage = "User not found."
                return
            }

            // Step 3: Check if the user is banned in Firestore
            let isBanned = try await checkIfUserIsBanned(email: email)
            if isBanned {
                self.errorMessage = "Your account has been locked due to a violation of principles."
                return
            }

            // Step 4: Sign in using Firebase Authentication
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                } else {
                    self.isLoggedIn = true
                    self.showMainContent = true
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    private let userFetcher = UserFetcher()

    private func fetchFirestoreUserEmail(for usernameOrEmail: String) async throws -> String? {
        // Fetch user via UserFetcher, passing nil for Firestore
        let user = try await userFetcher.fetchUser(usernameOrEmail: usernameOrEmail, context: nil as NSManagedObjectContext?)
        return user.email
    }
    
    private func checkIfUserIsBanned(email: String) async throws -> Bool {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(email)
        
        let document = try await userDoc.getDocument()
        if let data = document.data(), let isBanned = data["isBanned"] as? Bool {
            return isBanned
        }
        
        return false
    }
    
    // Fetch user from CoreData (fetch by email or username)
    private func fetchUser(_ usernameOrEmail: String, viewContext: NSManagedObjectContext) throws -> UserInfo {
        let normalizedEmail = usernameOrEmail.lowercased()  // Normalize the email/username input to lowercase
        
        let request = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        
        // Apply case-insensitive comparison on both userName and email
        request.predicate = NSPredicate(format: "userName ==[c] %@ OR email ==[c] %@", normalizedEmail, normalizedEmail)
        
        do {
            let results = try viewContext.fetch(request)
            
            // Ensure a user is found
            guard let user = results.first else {
                throw NSError(domain: "User not found", code: 404, userInfo: nil)
            }
            
            // Ensure email is set
            if user.email.isEmpty {
                throw NSError(domain: "User email not found.", code: 404, userInfo: nil)
            }
            
            return user
        } catch {
            throw error // Propagate the error if fetch fails
        }
    }


    // Sign in using a username (implement as necessary)
    private func signInUser(with username: String, password: String) async throws {
        // Your logic for signing in with username here (if needed)
    }
}
