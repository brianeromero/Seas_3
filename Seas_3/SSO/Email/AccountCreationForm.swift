//
//  AccountCreationForm.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import CoreData
import CryptoKit
import FirebaseAuth


struct AccountCreationFormView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var userName: String = "" // Add userName state
    @State private var name: String = "" // Add name state
    @State private var belt: String = ""
    @State private var errorMessage: String = ""
    let beltOptions = ["White", "Kids", "Blue", "Purple", "Brown", "Black", "Red", "Coral"]

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

            // Belt Picker
            Picker("Belt", selection: $belt) {
                ForEach(beltOptions, id: \.self) {
                    Text($0)
                }
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

        if !isValidPassword(password) {
            errorMessage = "Password must be at least 8 characters, contain uppercase, lowercase, and digits."
            return
        }

        // Check if email already exists
        if EmailUtility.fetchUserInfo(byEmail: email) != nil {
            errorMessage = "Email already exists."
            return
        }

        // Hash password using a do-catch block to handle errors
        do {
            let hashedPassword = try hashPassword(password)
            let passwordHashData = try JSONEncoder().encode(hashedPassword)

            let sanitizedEmail = sanitizeInput(email)
            let sanitizedUserName = sanitizeInput(userName)
            let sanitizedName = sanitizeInput(name)

            // Create new user with required fields
            Auth.auth().createUser(withEmail: sanitizedEmail, password: password) { result, error in
                if let error = error {
                    print("Error creating user: \(error.localizedDescription)")
                    self.errorMessage = "Failed to create user: \(error.localizedDescription)"
                    return
                }

                // Create new user in Core Data
                let newUser = UserInfo(context: self.managedObjectContext)
                newUser.userID = UUID() // Generate unique user ID
                newUser.email = sanitizedEmail // Required field
                newUser.passwordHash = passwordHashData // Required field
                newUser.userName = sanitizedUserName // Required field
                newUser.name = sanitizedName // Required field
                newUser.belt = self.belt // Optional field

                // Store new user securely
                self.storeUser(newUser)

                // Send account creation confirmation email
                let emailService = EmailService()
                emailService.sendAccountCreationConfirmationEmail(to: sanitizedEmail, userName: sanitizedUserName) { success in
                    if success {
                        print("Account creation confirmation email sent successfully")
                    } else {
                        print("Failed to send account creation confirmation email")
                    }
                }

                // Send welcome email
                let emailManager = UnifiedEmailManager(managedObjectContext: self.managedObjectContext)
                emailManager.sendWelcomeEmail(to: sanitizedEmail, userName: sanitizedUserName) { success in
                    if success {
                        print("Welcome email sent successfully")
                    } else {
                        print("Failed to send welcome email")
                    }
                }

                // Login new user
                self.authenticationState.login(newUser)

                // Send email verification
                result?.user.sendEmailVerification(completion: { error in
                    if let error = error {
                        print("Error sending email verification: \(error.localizedDescription)")
                        return
                    }

                    print("Email verification sent successfully")
                })
            }
        } catch {
            errorMessage = "Failed to hash password: \(error)"
        }
    }

    private func sanitizeInput(_ input: String) -> String {
        return input.trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))
    }

    private func isValidPassword(_ password: String) -> Bool {
        // Check for password length, special characters, and digits
        let passwordRegEx = "^(?=.*[A-Z])(?=.*[0-9])(?=.*[a-z]).{8,}$"
        let passwordTest = NSPredicate(format: "SELF MATCHES %@", passwordRegEx)
        return passwordTest.evaluate(with: password)
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

    private func storeUser(_ user: UserInfo) {
        user.isVerified = false

        // Fetch user from Core Data
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "email == %@", user.email)

        do {
            let users = try managedObjectContext.fetch(request)
            if let existingUser = users.first {
                existingUser.isVerified = false
            }

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
