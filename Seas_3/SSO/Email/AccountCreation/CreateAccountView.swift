//  CreateAccountView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import CoreData
import CryptoKit
import Firebase
import FirebaseAuth
import FirebaseAppCheck
import CryptoSwift
import Combine

extension String {
    var isAlphanumeric: Bool {
        let alphanumericSet = CharacterSet.alphanumerics
        return self.rangeOfCharacter(from: alphanumericSet.inverted) == nil
    }
}
import SwiftUI
import CoreData
import Firebase
import Combine

struct CreateAccountView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Binding var isUserProfileActive: Bool
    @State private var formState: FormState = FormState()
    @State private var belt: String = ""
    @State private var bypassValidation = false
    @StateObject var authViewModel = AuthViewModel()
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var shouldNavigateToLogin = false
    
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
    @State private var showLoginReset = false

    
    
    let emailManager: UnifiedEmailManager
    
    init(islandViewModel: PirateIslandViewModel,
         isUserProfileActive: Binding<Bool>,
         persistenceController: PersistenceController,
         emailManager: UnifiedEmailManager = .shared) {
        self._islandViewModel = ObservedObject(wrappedValue: islandViewModel)
        self._isUserProfileActive = isUserProfileActive
        self.emailManager = emailManager
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title and error message
                Text("Create Account")
                    .font(.largeTitle)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.bottom)
                }
                
                // Login Information
                Section(header: Text("Login Information").fontWeight(.bold)) {
                    UserNameField(
                        userName: $formState.userName,
                        isValid: $formState.isUserNameValid,
                        errorMessage: $formState.userNameErrorMessage,
                        validateUserName: { userName in ValidationUtility.validateField(userName, type: .userName) }
                    )
                    .padding(.bottom, 10)
                    
                    NameField(
                        name: $formState.name,
                        isValid: $formState.isNameValid,
                        errorMessage: $formState.nameErrorMessage,
                        validateName: ValidationUtility.validateName
                    )
                    .padding(.bottom, 10)
                    
                    EmailField(
                        email: $formState.email,
                        isValid: $formState.isEmailValid,
                        errorMessage: $formState.emailErrorMessage,
                        validateEmail: ValidationUtility.validateEmail
                    )
                    .padding(.bottom, 10)
                    
                    PasswordField(
                        password: $formState.password,
                        isValid: $formState.isPasswordValid,
                        errorMessage: $formState.passwordErrorMessage,
                        bypassValidation: $bypassValidation,
                        validatePassword: ValidationUtility.isValidPassword
                    )
                    .padding(.bottom, 10)
                    
                    ConfirmPasswordField(
                        confirmPassword: $formState.confirmPassword,
                        isValid: $formState.isConfirmPasswordValid,
                        password: $formState.password
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    if !formState.password.isEmpty && !formState.confirmPassword.isEmpty {
                        Image(systemName: formState.password == formState.confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .imageScale(.large)
                            .fontWeight(.bold)
                            .foregroundColor(formState.password == formState.confirmPassword ? Color(.systemGreen) : Color(.systemRed))
                    }
                }
                
                // Belt (optional)
                Section(header: HStack {
                    Text("Belt")
                    Text("(Optional)")
                        .foregroundColor(.gray)
                        .opacity(0.7)
                }) {
                    Menu {
                        ForEach(beltOptions, id: \.self) { belt in
                            Button(action: {
                                self.belt = belt
                            }) {
                                Text(belt)
                            }
                        }
                    } label: {
                        HStack {
                            Text(belt.isEmpty ? "Select a belt" : belt)
                                .foregroundColor(belt.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // Gym Information (optional)
                Section(header: HStack {
                    Text("Gym Information")
                        .fontWeight(.bold)
                    Text("(Optional)")
                        .foregroundColor(.gray)
                        .opacity(0.7)
                }) {
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
                        showAlert: .constant(false), // Modify as needed
                        alertMessage: .constant("") // Modify as needed
                    )
                }
                
                // Call-to-action
                Button(action: createAccount) {
                    Text("Create Account")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!formState.isValid)
                .padding(.bottom)
            }
            .padding()
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK")) {
                    self.shouldNavigateToLogin = true
                    isUserProfileActive = false
                    authenticationState.isLoggedIn = false
                    authenticationState.isAuthenticated = false
                }
            )
        }
        .navigationDestination(isPresented: $shouldNavigateToLogin) {
            LoginView(
                islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                persistenceController: PersistenceController.shared,
                isSelected: .constant(.login),
                navigateToAdminMenu: .constant(false),
                isLoggedIn: .constant(false)
            )
        }
    }
    
    
    // MARK: - Create Account Functionality
    /// Creates a new user account.
    private func createAccount() {
        print("Create Account button pressed.")
        print("Current form state: \(formState)")
        
        guard formState.password == formState.confirmPassword else {
            errorMessage = AccountAuthViewError.passwordMismatch.errorDescription!
            showErrorAlert = true
            return
        }
        
        guard formState.isPasswordValid else {
            errorMessage = AccountAuthViewError.invalidPassword.errorDescription!
            showErrorAlert = true
            return
        }
        
        Task {
            do {
                try await createUser()
                handleSuccess()
            } catch {
                handleCreateAccountError(error)
            }
        }
    }
    
    /// Creates a new user using the authentication view model.
    private func createUser() async throws {
        print("Entering createUser method.")
        print("Sending data to Firebase for account creation: Email: \(formState.email), UserName: \(formState.userName), Name: \(formState.name)")
        
        try await authViewModel.createUser(
            withEmail: formState.email,
            password: formState.password,
            userName: formState.userName,
            name: formState.name
        )
        print("Data sent to Firebase successfully.")
        
        // Add data to Core Data and Firestore
        print("Saving data to Core Data.")
        // Insert Core Data save logic here, if applicable
        
        print("Saving data to Firestore.")
        // Insert Firestore save logic here, if applicable
        print("Exiting createUser method.")
    }
    
    /// Handles successful account creation.
    private func handleSuccess() {
        print("Account created successfully. Preparing to send verification emails...")
        
        // Send Firebase email verification
        UnifiedEmailManager.shared.sendEmailVerification(to: formState.email) { success in
            print("Firebase email verification sent: \(success)")
            if !success {
                print("Error sending Firebase email verification.")
            } else {
                print("Firebase email verification sent successfully to \(self.formState.email).")
            }
        }

        // Send custom verification token email
        Task {
            let success = await UnifiedEmailManager.shared.sendVerificationToken(
                to: formState.email,
                userName: formState.userName,
                password: formState.password
            )
            
            print("Custom verification token email sent: \(success)")
            if !success {
                print("Error sending custom verification token email.")
            } else {
                print("Custom verification token email sent successfully to \(self.formState.email).")
            }
        }
        
        errorMessage = "Account created successfully. Check your email for login instructions."
        showErrorAlert = true
        
        // Reset authentication state
        authenticationState.isAuthenticated = false
        authenticationState.isLoggedIn = false
        
        // Navigate back to login
        isUserProfileActive = false
    }

    
    
    
    /// Handles create account errors, including existing user error.
    func handleCreateAccountError(_ error: Error) {
        let errorCode = (error as NSError).code
        
        switch errorCode {
        case 17011:
            errorMessage = "Invalid email or password."
        case 17008:
            errorMessage = "User not found."
        case 7:
            errorMessage = "Missing or insufficient permissions."
        case 17007, AuthErrorCode.emailAlreadyInUse.rawValue:
            errorMessage = AccountAuthViewError.userAlreadyExists.errorDescription
        default:
            errorMessage = "Error creating account: \(error.localizedDescription)"
        }
        
        showErrorAlert = true
        
        print("Create account error: \(errorMessage ?? "Unknown error")")
        
        // Reset authentication state
        authenticationState.isAuthenticated = false
        authenticationState.isLoggedIn = false
        authenticationState.navigateToAdminMenu = false
        
        isUserProfileActive = false
    }
}
    
    
    
// Preview
struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        CreateAccountView(
            islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
            isUserProfileActive: .constant(false),
            persistenceController: PersistenceController.preview,
            emailManager: UnifiedEmailManager.shared
        )
        .environmentObject(AuthenticationState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
