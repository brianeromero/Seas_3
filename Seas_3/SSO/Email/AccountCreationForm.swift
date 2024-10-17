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
import CryptoSwift
import Combine

extension SHA256.Digest {
    var hexEncoded: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    var isAlphanumeric: Bool {
        let alphanumericSet = CharacterSet.alphanumerics
        return self.rangeOfCharacter(from: alphanumericSet.inverted) == nil
    }
}


struct AccountCreationFormView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var userName: String = ""
    @State private var name: String = ""
    @State private var belt: String = ""
    @State private var bypassValidation = false

    @State private var showVerificationAlert = false
    @State private var errorMessage: String = ""

    let beltOptions = ["White", "Blue", "Purple", "Brown", "Black", "Red&Black", "Red&White", "Red"]

    @ObservedObject var islandViewModel: PirateIslandViewModel

    @State private var islandName = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?
    @State private var selectedProtocol = "http://"
    @State private var showAlert = false
    
    // For Inline Validation
    @State private var alertMessage = ""
    @State private var isUserNameValid: Bool = true
    @State private var isEmailValid: Bool = true
    @State private var isPasswordValid: Bool = true
    @State private var isConfirmPasswordValid: Bool = true
    @State private var isNameValid: Bool = true
    
    init(islandViewModel: PirateIslandViewModel, context: NSManagedObjectContext) {
        _islandViewModel = ObservedObject(wrappedValue: islandViewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .padding(.top)

                Text("* Required fields")
                    .foregroundColor(.red)
                    .font(.caption)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                VStack(spacing: 20) {
                    Section(header: Text("User Information").fontWeight(.bold)) {
                        UserNameField(username: $userName, isValid: $isUserNameValid, validateUsername: validateUsername)
                        NameField(name: $name, isValid: $isNameValid, validateName: validateName)
                        EmailField(email: $email, isValid: $isEmailValid, validateEmail: validateEmail)
                    }

                    Section(header: Text("Password").fontWeight(.bold)) {
                        PasswordField(password: $password, isValid: $isPasswordValid, bypassValidation: $bypassValidation, validatePassword: isValidPassword)
                        ConfirmPasswordField(confirmPassword: $confirmPassword, isValid: $isConfirmPasswordValid, password: $password)
                    }

                    Section(header: Text("")) {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Belt")
                                Text("(Optional)")
                                    .foregroundColor(.gray)
                                    .opacity(0.7)
                            }
                            Menu {
                                ForEach(beltOptions, id: \.self) { belt in
                                    Button(action: {
                                        self.belt = belt // Set the selected belt
                                    }) {
                                        Text(belt)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(belt.isEmpty ? "Select your belt" : belt) // Show selected belt or placeholder
                                        .foregroundColor(belt.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down") // Add dropdown arrow
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }

                    Section(header: HStack {
                        Text("Gym Information")
                            .fontWeight(.bold)
                        Text("(Optional)")
                            .foregroundColor(.gray)
                            .opacity(0.7)
                    }) {
                        Section(header: Text("Where I Train").fontWeight(.bold)) {
                            IslandFormSections(
                                viewModel: islandViewModel,
                                islandName: $islandName,
                                street: $street,
                                city: $city,
                                state: $state,
                                zip: $zip,
                                gymWebsite: $gymWebsite,
                                gymWebsiteURL: $gymWebsiteURL,
                                selectedProtocol: $selectedProtocol,
                                showAlert: $showAlert,
                                alertMessage: $alertMessage
                            )
                        }
                    }
                }
                .padding() // Add padding around the form sections

                Button(action: {
                    self.createAccount()
                }) {
                    Text("Create Account")
                        .frame(maxWidth: .infinity) // Make button full width
                        .padding() // Add padding to button
                        .background(Color.blue) // Background color
                        .foregroundColor(.white) // Text color
                        .cornerRadius(8) // Rounded corners
                }
                .disabled(!isCreateAccountEnabled())
                .padding(.bottom) // Add bottom padding for the button
            }
            .padding()
            .navigationTitle("Create Account")
            .alert(isPresented: $showVerificationAlert) {
                Alert(
                    title: Text("Account Created"),
                    message: Text("Please check your email for verification link. Check spam folder if not found."),
                    dismissButton: .default(Text("OK")) {
                        self.authenticationState.logout()
                    }
                )
            }
        }
    }

    private func validateForm() -> Bool {
        return !userName.isEmpty && !email.isEmpty && !password.isEmpty && (password == confirmPassword)
    }

    //REUSABLE FIELD VIEWS
    struct UserNameField: View {
        @Binding var username: String
        @Binding var isValid: Bool
        var validateUsername: (String) -> String?

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text("Username")
                    Text("*").foregroundColor(.red)  // Add red asterisk
                }
                TextField("Enter your username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: username) { newValue in
                        let validationMessage = validateUsername(newValue)
                        isValid = validationMessage == nil
                        // Update errorMessage here if needed
                    }
                if !isValid {
                    Text(validateUsername(username) ?? "")  // Display error message
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
    }

    struct NameField: View {
        @Binding var name: String
        @Binding var isValid: Bool
        var validateName: (String) -> String?

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text("Name")
                    Text("*").foregroundColor(.red)  // Add red asterisk
                }
                TextField("Enter your name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: name) { newValue in
                        isValid = validateName(newValue) == nil // Update to reflect new validation logic
                    }
                // Optionally, if you want to keep a message here, you can say something like:
                if !isValid {
                    Text("Name can contain any characters.")
                        .foregroundColor(.gray)
                        .font(.caption) // Optional informational message
                }
            }
        }
    }
    
    
    struct EmailField: View {
        @Binding var email: String
        @Binding var isValid: Bool
        var validateEmail: (String) -> String?

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text("Email")
                    Text("*").foregroundColor(.red)  // Add red asterisk
                }
                TextField("Enter your email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: email) { newValue in
                        isValid = validateEmail(newValue) == nil // Update to reflect new validation logic
                    }
                if !isValid {
                    Text(validateEmail(email) ?? "")  // Display error message
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
    }

    struct PasswordField: View {
        @Binding var password: String
        @Binding var isValid: Bool
        @Binding var bypassValidation: Bool
        var validatePassword: (String) -> Bool

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text("Password")
                    Text("*").foregroundColor(.red)  // Add red asterisk
                }
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: password) { newValue in
                        if !bypassValidation {
                            isValid = validatePassword(newValue)
                        } else {
                            isValid = true
                        }
                    }
                if !isValid && !bypassValidation {
                    Text("Password must be at least 8 characters, contain uppercase, lowercase, and digits.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                HStack {
                    Toggle("Bypass password validation", isOn: $bypassValidation)
                        .toggleStyle(SwitchToggleStyle())
                    Text("Use at your own risk")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
        }
    }

    struct ConfirmPasswordField: View {
        @Binding var confirmPassword: String
        @Binding var isValid: Bool
        @Binding var password: String

        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Text("Confirm Password")
                    Text("*").foregroundColor(.red)  // Add red asterisk
                }
                SecureField("Confirm your password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: confirmPassword) { _ in
                        isValid = confirmPassword == password
                    }
                if !isValid {
                    Text("Passwords do not match.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Create Account Functionality
    private func createAccount() {
        guard validateForm() else {
            errorMessage = "Please fill out all required fields correctly."
            return
        }

        if password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                errorMessage = "Error creating account: \(error.localizedDescription)"
                return
            }

            guard let user = result?.user else { return }

            _ = user.uid
            let hashedPassword = try? hashPassword(password) // Use your hash method

            // Ensure that the 'userID' property in Core Data is set correctly
            let userInfo = UserInfo(context: managedObjectContext)
            userInfo.userID = UUID() // Use UUID if you need a new unique identifier
            userInfo.email = email
            userInfo.userName = userName
            userInfo.name = name
            userInfo.belt = belt
            userInfo.passwordHash = hashedPassword?.data(using: .utf8) ?? Data() // Convert to Data if needed

            storeUser(userInfo) // Save the user

            self.showVerificationAlert = true
        }
    }


    private func validateUsername(_ username: String) -> String? {
        if username.count < 7 || !username.isAlphanumeric {
            return "Username should be at least 7 characters long and contain only alphanumeric characters."
        } else if usernameIsTaken(username) {
            return "Username already exists."
        }
        return nil
    }
    
    // Define usernameIsTaken function
    private func usernameIsTaken(_ username: String) -> Bool {
        // Logic to check if username is taken
        // Replace with actual implementation
        return false
    }

    private func validateName(_ name: String) -> String? {
        // You can keep this function empty if you don't want any validation
        return nil // No validation needed
    }

    private func isCreateAccountEnabled() -> Bool {
        return !userName.isEmpty && isUserNameValid &&
               !email.isEmpty && isEmailValid &&
               !password.isEmpty && isPasswordValid &&
               !confirmPassword.isEmpty && isConfirmPasswordValid
    }

    private func validateEmail(_ email: String) -> String? {
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@",
                                         "^[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}$")
        if !emailPredicate.evaluate(with: email) {
            return "Invalid email format. Please use 'example@example.com'."
        }
        return nil
    }

    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        if !passwordPredicate.evaluate(with: password) {
            // Optionally, provide feedback here
            return false
        }
        return true
    }


    private func hashPassword(_ password: String) throws -> String {
        let data = password.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }

    private func storeUser(_ user: UserInfo) {
        do {
            try managedObjectContext.save()
        } catch {
            print("Error saving user to Core Data: \(error.localizedDescription)")
            self.errorMessage = "Failed to save user information."
        }
    }

    private func fetchUserByEmail(_ email: String) -> UserInfo? {
        let fetchRequest = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        fetchRequest.predicate = NSPredicate(format: "email == %@", email)

        do {
            let users = try managedObjectContext.fetch(fetchRequest)
            return users.first
        } catch {
            print("Error fetching user by email: \(error.localizedDescription)")
            return nil
        }
    }
}


struct AccountCreationFormView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        AccountCreationFormView(islandViewModel: PirateIslandViewModel(persistenceController: persistenceController), context: persistenceController.container.viewContext)
            .environmentObject(AuthenticationState())
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Account Creation Form")
    }
}
