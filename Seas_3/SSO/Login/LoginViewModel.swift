//
//  LoginViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 11/13/24.
//

import Foundation
import FirebaseAuth
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

        // Check if usernameOrEmail is a valid email
        if validateEmail(usernameOrEmail) {
            do {
                let user = try fetchUser(usernameOrEmail, viewContext: viewContext)
                let email = user.email
                Auth.auth().signIn(withEmail: email, password: password) { result, error in
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.isLoggedIn = true
                        self.showMainContent = true
                    }
                }
            } catch {
                self.errorMessage = "User not found."
            }
        } else {
            // Handle username login (assuming your `signInUser` method handles username)
            do {
                try await signInUser(with: usernameOrEmail, password: password)
                self.isLoggedIn = true
                self.showMainContent = true
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // Fetch user from CoreData (fetch by email or username)
    private func fetchUser(_ usernameOrEmail: String, viewContext: NSManagedObjectContext) throws -> UserInfo {
        let request = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        request.predicate = NSPredicate(format: "userName == %@ OR email == %@", usernameOrEmail, usernameOrEmail)
        
        let results = try viewContext.fetch(request)
        guard let user = results.first else {
            throw NSError(domain: "User not found", code: 404, userInfo: nil)
        }
        
        // Ensure email is set
        if user.email.isEmpty {
            throw NSError(domain: "User email not found.", code: 404, userInfo: nil)
        }
        
        return user
    }

    // Sign in using a username (implement as necessary)
    private func signInUser(with username: String, password: String) async throws {
        // Your logic for signing in with username here (if needed)
    }
}
