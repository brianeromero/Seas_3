//
//  AccountCreationForm.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import CoreData

struct AccountCreationFormView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var userName: String = "" // Add userName state
    @State private var name: String = "" // Add name state
    @State private var belt: String = "" // Add belt state
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.largeTitle)

            Text("Enter the following information to create an account:")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom)

            // User Name Field
            VStack(alignment: .leading) {
                Text("Username") // Header for the Username field
                TextField("Enter your username", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Name Field
            VStack(alignment: .leading) {
                Text("Name") // Header for the Name field
                TextField("Enter your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Email Field
            VStack(alignment: .leading) {
                Text("Email Address") // Header for the Email field
                TextField("Email address", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }

            // Password Field
            VStack(alignment: .leading) {
                Text("Password") // Header for the Password field
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Confirm Password Field
            VStack(alignment: .leading) {
                Text("Confirm Password") // Header for the Confirm Password field
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Create Account Button
            Button(action: {
                self.createAccount()
            }) {
                Text("Create Account")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 200)
                    .background(isCreateAccountEnabled() ? Color.blue : Color.gray) // Disable button if validation fails
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isCreateAccountEnabled()) // Disable button based on validation

            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .navigationTitle("Create Account")
    }

    private func createAccount() {
        // Validate email and password
        if email.isEmpty || password.isEmpty || userName.isEmpty || name.isEmpty {
            errorMessage = "Please fill in all fields."
            return
        }

        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address."
            return
        }

        if password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }

        // Check if email already exists
        if fetchUserByEmail(email) != nil {
            errorMessage = "Email already exists."
            return
        }

        // Hash password
        guard let hashedPassword = hashPassword(password) else {
            errorMessage = "Failed to hash password."
            return
        }

        // Create new user with required fields
        let newUser = UserInfo(context: managedObjectContext)
        newUser.userID = UUID() // Generate unique user ID
        newUser.email = email // Required field
        newUser.passwordHash = hashedPassword // Required field
        newUser.userName = userName // Required field
        newUser.name = name // Required field
        newUser.belt = belt // Optional field

        // Store new user securely
        storeUser(newUser)

        // Login new user
        authenticationState.login(newUser)
    }


    private func isCreateAccountEnabled() -> Bool {
        // Check if all fields are filled and if email is valid
        return !email.isEmpty && !password.isEmpty && !userName.isEmpty && !name.isEmpty && password == confirmPassword && isValidEmail(email)
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Regular expression for validating email format
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }

    private func fetchUserByEmail(_ email: String) -> UserInfo? {
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "email == %@", email)

        do {
            let users = try managedObjectContext.fetch(request)
            return users.first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }

    private func storeUser(_ user: UserInfo) {
        do {
            try managedObjectContext.save() // Save changes to the context
        } catch {
            print("Error creating user: \(error.localizedDescription)")
        }
    }
}

struct AccountCreationFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountCreationFormView()
                .environmentObject(AuthenticationState())
        }
        .previewDisplayName("AccountCreationFormView")
    }
}