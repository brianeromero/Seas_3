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

struct CreateAccountView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Binding var isUserProfileActive: Bool
    @State private var formState: FormState = FormState()
    @State private var belt: String = ""
    @State private var bypassValidation = false
    @StateObject var authViewModel = AuthViewModel()
    
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
    @State private var showErrorAlert = false
    
    // For Inline Validation
    @State private var alertMessage = ""
    
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
                if !errorMessage.isEmpty {
                    Text(errorMessage)
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
                        if formState.password == formState.confirmPassword {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemGreen))
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemRed))
                        }
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
                            Text(belt)
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
                        showAlert: $showAlert,
                        alertMessage: $alertMessage
                    )
                }
                
                // Call-to-action
                Button(action: {
                    print("Button clicked")
                    print("Form valid: \(formState.isValid)")
                    self.createAccount()
                }) {
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
            .navigationTitle("Create Account")
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .showErrorAlert(isPresented: $showErrorAlert, message: errorMessage)
        }
    }
    
    // MARK: - Create Account Functionality
    private func createAccount() {
        print("Create Account button clicked")
        print("Checking password match")
        
        // Check password match
        if formState.password != formState.confirmPassword {
            print("Password mismatch")
            errorMessage = AccountAuthViewError.passwordMismatch.errorDescription!
            return
        }
        print("Passwords match")
        
        print("Checking password validity")
        
        // Check password validity
        if !formState.isPasswordValid {
            print("Password invalid")
            errorMessage = AccountAuthViewError.invalidPassword.errorDescription!
            return
        }
        print("Password valid")
        
        print("Calling createUser")
        
        Task {
            let result = await authViewModel.createUser(withEmail: formState.email,
                                                        password: formState.password,
                                                        userName: formState.userName,
                                                        name: formState.name)
            
            switch result {
            case .success:
                if !authViewModel.errorMessage.isEmpty {
                    errorMessage = authViewModel.errorMessage
                    errorMessage = "You have created an account; a separate email should be received with login instructions."
                    showErrorAlert = true
                }
            case .failure(let error):
                print("Error creating account: \(error.localizedDescription)")
                
                if let errorCode = AuthErrorCode(rawValue: error._code) {
                    switch errorCode {
                    case .emailAlreadyInUse:
                        errorMessage = "Email already in use. Please try another email."
                        showErrorAlert = true
                    default:
                        errorMessage = AccountAuthViewError.unknownError.errorDescription!
                        showErrorAlert = true
                    }
                }
            }
        }
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
