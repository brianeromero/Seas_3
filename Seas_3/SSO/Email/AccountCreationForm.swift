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
<<<<<<< HEAD
import FirebaseAuth
=======
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9

struct AccountCreationFormView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var userName: String = "" // Add userName state
    @State private var name: String = "" // Add name state
    @State private var belt: String = ""
<<<<<<< HEAD
    @State private var showVerificationAlert = false
    @State private var errorMessage: String = ""
    let beltOptions = ["White", "Blue", "Purple", "Brown", "Black", "Red&Black", "Red&White", "Red"]

    // Use @ObservedObject instead of @StateObject
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
    @State private var alertMessage = ""

    init(islandViewModel: PirateIslandViewModel, context: NSManagedObjectContext) {
        _islandViewModel = ObservedObject(wrappedValue: islandViewModel)
        // Initialize with context
    }

    var body: some View {
        ScrollView {
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
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 0))
                    }
                }

                // Optional "Where I Train" section for gym details
                islandDetailsSection
                websiteSection

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
=======
    @State private var errorMessage: String = ""
    let beltOptions = ["White", "Kids", "Blue", "Purple", "Brown", "Black","Red", "Coral"]

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

            // Belt Field
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
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
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
<<<<<<< HEAD
        if EmailUtility.fetchUserInfo(byEmail: email) != nil {
=======
        if fetchUserByEmail(email) != nil {
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
            errorMessage = "Email already exists."
            return
        }

<<<<<<< HEAD
        // Check if username already exists
        if EmailUtility.fetchUserInfo(byUsername: userName) != nil {
            errorMessage = "Username already exists. Please choose another username."
            return
        }

=======
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
        // Hash password using a do-catch block to handle errors
        do {
            let hashedPassword = try hashPassword(password)
            let passwordHashData = try JSONEncoder().encode(hashedPassword)

            let sanitizedEmail = sanitizeInput(email)
            let sanitizedUserName = sanitizeInput(userName)
            let sanitizedName = sanitizeInput(name)

            // Create new user with required fields
<<<<<<< HEAD
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

                // Send verification email (which now includes welcome message)
                let emailManager = UnifiedEmailManager(managedObjectContext: self.managedObjectContext)
                let verificationToken = UUID().uuidString

                // Update user verification token
                let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
                request.predicate = NSPredicate(format: "email == %@", sanitizedEmail)

                do {
                    let users = try managedObjectContext.fetch(request)
                    if let existingUser = users.first {
                        existingUser.verificationToken = verificationToken
                        try managedObjectContext.save()
                    }
                } catch {
                    print("Error updating user verification token: \(error.localizedDescription)")
                }

                emailManager.verifyEmail(token: verificationToken, email: sanitizedEmail, userName: sanitizedUserName) { success in
                    if success {
                        print("Verification and welcome email sent successfully")
                        self.showVerificationAlert = true
                    } else {
                        print("Failed to send verification and welcome email")
                    }
                }
            }
        } catch {
            print("Error hashing password: \(error.localizedDescription)")
            errorMessage = "Failed to hash password."
=======
            let newUser = UserInfo(context: managedObjectContext)
            newUser.userID = UUID() // Generate unique user ID
            newUser.email = sanitizedEmail // Required field
            newUser.passwordHash = passwordHashData // Required field
            newUser.userName = sanitizedUserName // Required field
            newUser.name = sanitizedName // Required field
            newUser.belt = belt // Optional field

            // Store new user securely
            storeUser(newUser)

            // Login new user
            authenticationState.login(newUser)
        } catch {
            errorMessage = "Failed to hash password: \(error)"
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
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
<<<<<<< HEAD
        return !email.isEmpty && !password.isEmpty && password == confirmPassword && !userName.isEmpty && !name.isEmpty && isValidEmail(email)
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Validate email format using regex
=======
        return !email.isEmpty && !password.isEmpty && !userName.isEmpty && !name.isEmpty && password == confirmPassword && isValidEmail(email)
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Regular expression for validating email format
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }

<<<<<<< HEAD
    private func hashPassword(_ password: String) throws -> String {
        let data = password.data(using: .utf8)!
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private var islandDetailsSection: some View {
        VStack(alignment: .leading) {
            Text("Where I Train (Optional)")

            TextField("Gym Name", text: $islandName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Street", text: $street)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("City", text: $city)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("State", text: $state)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Zip", text: $zip)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.bottom)
    }

    private var websiteSection: some View {
        VStack(alignment: .leading) {
            Text("Gym Website (Optional)").font(.headline)

            HStack {
                TextField("Website URL", text: $gymWebsite)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: gymWebsite) { newValue in
                        if let url = URL(string: selectedProtocol + newValue) {
                            gymWebsiteURL = url
                        } else {
                            gymWebsiteURL = nil
                        }
                    }
            }
        }
        .padding(.bottom)
=======
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
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
    }

    private func storeUser(_ user: UserInfo) {
        do {
<<<<<<< HEAD
            try managedObjectContext.save()
        } catch {
            print("Error saving user to Core Data: \(error.localizedDescription)")
=======
            try managedObjectContext.save() // Save changes to the context
        } catch {
            print("Error creating user: \(error.localizedDescription)")
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
        }
    }
}

<<<<<<< HEAD

struct AccountCreationFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        AccountCreationFormView(islandViewModel: PirateIslandViewModel(context: context), context: context)
            .environmentObject(AuthenticationState())
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Account Creation Form")
=======
struct AccountCreationFormView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AccountCreationFormView()
                .environmentObject(AuthenticationState())
        }
        .previewDisplayName("AccountCreationFormView")
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
    }
}
