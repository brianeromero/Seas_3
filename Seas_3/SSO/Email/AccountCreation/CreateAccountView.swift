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
import os.log

extension String {
    var isAlphanumeric: Bool {
        let alphanumericSet = CharacterSet.alphanumerics
        return self.rangeOfCharacter(from: alphanumericSet.inverted) == nil
    }
}

enum CreateAccountError: Int {
    case invalidEmailOrPassword = 17011
    case userNotFound = 17008
    case missingPermissions = 7
    case emailAlreadyInUse = 17007
}

// Ensure `FormFieldViews.swift` is accessible
struct CreateAccountView: View {
    // Environment and Context
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    // Navigation and Routing
    @Binding var isUserProfileActive: Bool
    @Binding var selectedTabIndex: Int
    @State private var shouldNavigateToLogin = false
    
    // Form State and Validation
    @State private var formState: FormState = FormState()
    @State private var bypassValidation = false
    @State private var showValidationMessage = false
    
    // View Models
    @StateObject var authViewModel = AuthViewModel()
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @StateObject var profileViewModel: ProfileViewModel
    @ObservedObject var countryService: CountryService
    
    // Account and Profile Information
    @State private var belt: String = ""
    let beltOptions = ["", "White", "Blue", "Purple", "Brown", "Black"]
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?
    @State private var selectedProtocol = "http://"
    @State private var province = ""
    @State private var selectedCountry: Country? = Country(name: Country.Name(common: "United States"), cca2: "US", flag: "")
    @State private var governorate = ""
    @State private var region = ""
    @State private var county = ""
    @State private var islandDetails = IslandDetails()
    
    // Address and Location
    @State private var neighborhood: String = ""
    @State private var complement: String = ""
    @State private var apartment: String = ""
    @State private var additionalInfo: String = ""
    
    // Alerts and Toasts
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    // Picker and Modal States
    @State private var isPickerPresented = false
    @State private var countries: [Country] = []
    
    let emailManager: UnifiedEmailManager
    
    init(
        islandViewModel: PirateIslandViewModel,
        isUserProfileActive: Binding<Bool>,
        persistenceController: PersistenceController,
        selectedTabIndex: Binding<Int>,
        countryService: CountryService = .shared,
        emailManager: UnifiedEmailManager = .shared
    ) {
        self._islandViewModel = ObservedObject(wrappedValue: islandViewModel)
        self._isUserProfileActive = isUserProfileActive
        self._selectedTabIndex = selectedTabIndex
        self.countryService = countryService
        self.emailManager = emailManager
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(viewContext: persistenceController.container.viewContext))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.bottom)
                }
                
                UserInformationView(formState: $formState)
                
                PasswordField(
                    password: $formState.password,
                    isValid: $formState.isPasswordValid,
                    errorMessage: $formState.passwordErrorMessage,
                    bypassValidation: $bypassValidation,
                    validateField: { password in
                        if let validationMessage = ValidationUtility.validateField(password, type: .password) {
                            return (false, validationMessage.rawValue)
                        } else {
                            return (true, "")
                        }
                    }
                )
                
                ConfirmPasswordField(
                    confirmPassword: $formState.confirmPassword,
                    isValid: $formState.isConfirmPasswordValid,
                    password: $formState.password
                )
                
                BeltSection(belt: $belt, beltOptions: ["", "White", "Blue", "Purple", "Brown", "Black"], usePickerStyle: true)
                
                Section(header: HStack {
                    Text("Gym Information")
                        .fontWeight(.bold)
                    Text("(Optional)")
                        .foregroundColor(.gray)
                        .opacity(0.7)
                }
                .padding(.horizontal, 20)) {
                    IslandFormSections(
                        viewModel: islandViewModel,
                        islandName: $islandDetails.islandName,
                        street: $islandDetails.street,
                        city: $islandDetails.city,
                        state: $islandDetails.state,
                        postalCode: $islandDetails.postalCode,
                        province: $province,
                        neighborhood: $neighborhood,
                        complement: $complement,
                        apartment: $apartment,
                        region: $region,
                        county: $county,
                        governorate: $governorate,
                        additionalInfo: $additionalInfo,
                        gymWebsite: $gymWebsite,
                        gymWebsiteURL: $gymWebsiteURL,
                        showAlert: .constant(false),
                        alertMessage: .constant(""),
                        selectedCountry: $selectedCountry,
                        islandDetails: $islandDetails,
                        profileViewModel: profileViewModel
                    )
                }
                
                // Validation logic
                let isIslandNameRequired = islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty
                let areAddressFieldsRequired = !isIslandNameRequired && !areAddressFieldsValid(for: selectedCountry?.cca2 ?? "", islandDetails: islandDetails)
                
                // Error Message for Island Name and Address Validation
                if isIslandNameRequired {
                    Text("Island name is required.")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 20)
                }
                if areAddressFieldsRequired {
                    Text("Please fill in all required address fields.")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 20)
                }
                
                // Form validity check
                var isValidForm: Bool {
                    // Make sure the user fields are valid
                    formState.isUserNameValid &&
                    formState.isNameValid &&
                    formState.isEmailValid &&
                    formState.isPasswordValid &&
                    formState.isConfirmPasswordValid &&
                    AddressFormIsValid &&
                    errorMessage == nil
                }
                
                // Form validity check
                // Address validation logic
                var AddressFormIsValid: Bool {
                    // If islandName is empty, address fields are not required
                    if islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty {
                        return true // Address fields aren't required if island name is empty
                    } else {
                        return areAddressFieldsValid(for: selectedCountry?.cca2 ?? "", islandDetails: islandDetails)
                    }
                }
                
                Button(action: {
                    print("Button tapped - calling createPirateIsland")

                    // Ensure currentUserId is defined and valid
                    guard let currentUserId = Auth.auth().currentUser?.uid else {
                        print("Error: User is not logged in")
                        return
                    }
                    
                    // Log the current user ID
                    print("Current User ID: \(currentUserId)")
                    
                    // Use async/await for async call
                    Task {
                        do {
                            // Ensure all required parameters are passed
                            let result = try await islandViewModel.createPirateIsland(
                                islandDetails: islandDetails,
                                createdByUserId: currentUserId, // Pass the current user ID here
                                gymWebsite: gymWebsiteURL?.absoluteString
                            )

                            // Handle the result if needed (you can inspect the result here if required)
                            print("Pirate Island created: \(result)")
                        } catch {
                            // Handle any errors that occur during the async call
                            print("Error creating Pirate Island: \(error)")
                            // You can also set a state variable to display an alert or a message based on the error
                        }
                    }

                    createAccount()
                    debugPrint("Button tapped - validating form")
                    debugPrint("formState isUserNameValid: \(formState.isUserNameValid)")
                    debugPrint("formState isEmailValid: \(formState.isEmailValid)")
                    debugPrint("formState isPasswordValid: \(formState.isPasswordValid)")
                    print("Island Name: '\(islandDetails.islandName)'")
                    print("Full Address: '\(islandDetails.fullAddress)'")
                    print("Form State - isUserNameValid: \(formState.isUserNameValid), isEmailValid: \(formState.isEmailValid)")
                    print("Attempting to create account")
                    
                    /*if isValidForm {
                        createAccount()
                    } else {
                        debugPrint("Form is invalid")
                        print("Form is invalid")
                        self.showValidationMessage = true
                    } */
                    
                    
                    
                }) {
                    Text("Create Account")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidForm ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!isValidForm) // Disable the button if the form is invalid
                .opacity(isValidForm ? 1 : 0.5)
                .padding(.bottom)
                .padding(.horizontal, 24)
                .onAppear {
                    print("Island Name: '\(islandDetails.islandName)'")
                    print("Full Address: '\(islandDetails.fullAddress)'")
                    print("Form State - isUserNameValid: \(formState.isUserNameValid), isEmailValid: \(formState.isEmailValid)")
                    
                    Task {
                        await countryService.fetchCountries()
                    }
                }
                .alert(isPresented: $showErrorAlert) {
                    Alert(
                        title: Text(successMessage != nil ? "Success" : "Error"),
                        message: Text(successMessage ?? errorMessage ?? "Unknown error"),
                        dismissButton: .default(Text("OK")) {
                            self.shouldNavigateToLogin = successMessage != nil
                            isUserProfileActive = false
                            authenticationState.isLoggedIn = false
                            authenticationState.isAuthenticated = false
                            successMessage = nil
                            errorMessage = nil
                        }
                    )
                }
                .navigationDestination(isPresented: $shouldNavigateToLogin) {
                    LoginView(
                        islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                        isSelected: .constant(LoginViewSelection(rawValue: selectedTabIndex) ?? .login),
                        navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                        isLoggedIn: $authenticationState.isLoggedIn
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    func addressField(for field: AddressField) -> some View {
        let binding = AddressBindingHelper.binding(for: field, islandDetails: $islandDetails)
        
        switch field {
        case .street:
            TextField("Enter street", text: binding)
        case .city:
            TextField("Enter city", text: binding)
        case .postalCode:
            TextField("Enter postal code", text: binding)
        case .county:
            TextField("Enter county", text: binding)
        case .country:
            TextField("Enter country", text: Binding(
                get: { selectedCountry!.name.common },
                set: { newValue in
                    selectedCountry = Country(name: Country.Name(common: newValue), cca2: selectedCountry!.cca2, flag: selectedCountry!.flag)
                }
            ))
        default:
            EmptyView()
        }
    }
    
    func areAddressFieldsValid(for countryCode: String, islandDetails: IslandDetails) -> Bool {
        let requiredFields = getAddressFields(for: countryCode) // Get the required address fields for the country
        for field in requiredFields {
            // Dynamically check each required address field based on its keyPath
            let keyPath = AddressField(rawValue: field.rawValue)?.keyPath ?? \.street
            let value = islandDetails[keyPath: keyPath].trimmingCharacters(in: .whitespaces)
            if value.isEmpty {
                return false
            }
        }
        return true
    }
    
    var isIslandNameRequired: Bool {
        // Check if island name is provided and thus address fields become required
        return !islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    
    func createAccount() {
        os_log("Create Account button pressed.", type: .info)
        logFormState()
        logAddressDetails()

        guard isValidForm() else { return }
        guard !emailAlreadyExists() else { return }

        Task {
            do {
                try await createUserAccount()
                await createPirateIslandIfValid()
                handleSuccess()
            } catch {
                handleCreateAccountError(error)
            }
        }
    }

    // MARK: - Helper Functions

    private func logFormState() {
        os_log("Current form state: %@", type: .info, "\(formState)")
        os_log("Validation Check: Username Valid: %d, Name Valid: %d, Email Valid: %d, Password Valid: %d", type: .info, formState.isUserNameValid, formState.isNameValid, formState.isEmailValid, formState.isPasswordValid)
    }

    private func logAddressDetails() {
        os_log("islandName: %@", type: .info, islandDetails.islandName)
        os_log("Island Name entered: %@", type: .info, islandDetails.islandName)
        os_log("fullAddress: %@", type: .info, islandDetails.fullAddress)
        os_log("Selected Country: %@", type: .info, selectedCountry?.name.common ?? "None")
    }

    private func isValidForm() -> Bool {
        guard formState.isEmailValid else {
            errorMessage = "Please enter a valid email address."
            showErrorAlert = true
            return false
        }
        guard !formState.name.isEmpty else {
            errorMessage = "Name is required."
            showErrorAlert = true
            return false
        }
        return true
    }

    private func emailAlreadyExists() -> Bool {
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", formState.email)

        do {
            let existingUsers = try managedObjectContext.fetch(fetchRequest)
            if !existingUsers.isEmpty {
                errorMessage = "A user with this email address already exists."
                showErrorAlert = true
                return true
            }
        } catch {
            handleCreateAccountError(error)
            return true
        }
        return false
    }

    private func createUserAccount() async throws {
        try await authViewModel.createUser(
            withEmail: formState.email,
            password: formState.password,
            userName: formState.userName,
            name: formState.name,
            belt: belt
        )
    }

    private func createPirateIslandIfValid() async {
        var (isValid, errorMessage) = ValidationUtility.validateIslandForm(
            islandName: islandDetails.islandName,
            street: islandDetails.street,
            city: islandDetails.city,
            state: islandDetails.state,
            postalCode: islandDetails.postalCode,
            neighborhood: neighborhood,
            complement: complement,
            province: province,
            region: region,
            governorate: governorate,
            selectedCountry: selectedCountry,
            createdByUserId: formState.userName,
            gymWebsite: gymWebsite
        )

        if !isValid {
            self.errorMessage = errorMessage
            showErrorAlert = true
            return
        }

        if !gymWebsite.isEmpty, let urlError = ValidationUtility.validateURL(gymWebsite) {
            errorMessage = "Invalid gym website URL: \(urlError)"
            showErrorAlert = true
            os_log("Invalid gym website URL", type: .error)
            return
        }

        if islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty ||
           islandDetails.fullAddress.trimmingCharacters(in: .whitespaces).isEmpty {
            os_log("Failed to meet conditions for createPirateIsland.", type: .error)
            return
        }

        os_log("Conditions met. Proceeding to createPirateIsland.", type: .info)

        do {
            _ = try await islandViewModel.createPirateIsland(
                islandDetails: islandDetails,
                createdByUserId: formState.userName,
                gymWebsite: gymWebsite.isEmpty ? nil : gymWebsite
            )
            toastMessage = "Island saved successfully!"
        } catch {
            handleCreateAccountError(error)
        }
    }
    
    
    private func handleCreateAccountError(_ error: Error) {
        os_log("Create account error occurred: %@", type: .error, error.localizedDescription)
        errorMessage = getErrorMessage(error)
        showErrorAlert = true

        print("Create account error: \(errorMessage ?? "Unknown error")")

        resetAuthenticationState()
    }

    
    /// Handles successful account creation.
    private func handleSuccess() {
        os_log("Account created successfully. Preparing to send verification emails...", type: .info)
        print("Account created successfully. Preparing to send verification emails...")

        sendVerificationEmails()
        successMessage = "Account created successfully. Check your email for login instructions."
        showErrorAlert = true
        resetAuthenticationState()
    }

    private func sendVerificationEmails() {
        let email = formState.email

        // Send Firebase email verification
        UnifiedEmailManager.shared.sendEmailVerification(to: email) { success in
            os_log("Firebase email verification sent: %d", type: .info, success)
            print("Firebase email verification sent: \(success)")
        }

        // Send custom verification token email
        Task {
            let success = await UnifiedEmailManager.shared.sendVerificationToken(
                to: email,
                userName: formState.userName,
                password: formState.password
            )
            print("Custom verification token email sent: \(success)")
            os_log("Custom verification token email sent: %d", type: .info, success)
        }
    }
    
    
    func getErrorMessage(_ error: Error) -> String {
        if let pirateIslandError = error as? PirateIslandError {
            switch pirateIslandError {
            case .invalidInput:
                return "Invalid input"
            case .islandExists:
                return "Island already exists"
            case .geocodingError(let message):
                return "Geocoding error: \(message)"
            case .savingError:
                return "Saving error"
            case .islandNameMissing:
                return "Island name is missing"
            case .streetMissing:
                return "Street address is missing"
            case .cityMissing:
                return "City is missing"
            case .stateMissing:
                return "State is missing"
            case .postalCodeMissing:
                return "Postal code is missing"
            case .fieldMissing(_):
                return "Some OTHER field is missing"
            case .invalidGymWebsite:
                return "Gym Website appears to be invalid"
            }
            
        } else {
            let errorCode = (error as NSError).code
            switch CreateAccountError(rawValue: errorCode) {
            case .invalidEmailOrPassword:
                return "Invalid email or password."
            case .userNotFound:
                return "User not found."
            case .missingPermissions:
                return "Missing or insufficient permissions."
            case .emailAlreadyInUse:
                return AccountAuthViewError.userAlreadyExists.errorDescription ?? "Email already in use."
            default:
                return "Error creating account: \(error.localizedDescription)"
            }
        }
    }
    
    private func resetAuthenticationState() {
        authenticationState.isAuthenticated = false
        authenticationState.isLoggedIn = false
        authenticationState.navigateToAdminMenu = false
        isUserProfileActive = false
    }
}


struct BeltSection: View {
    @Binding var belt: String
    let beltOptions: [String]
    var usePickerStyle: Bool
    
    var body: some View {
        Section(header: HStack {
            Text("Belt")
            Text("(Optional)")
                .foregroundColor(.gray)
                .opacity(0.7)
        }
        .padding(.horizontal, 20)) {
            if usePickerStyle {
                Picker("Select your belt", selection: $belt) {
                    ForEach(beltOptions, id: \.self) { beltOption in
                        Text(beltOption).tag(beltOption)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal, 20)
                .onAppear {
                    if belt.isEmpty {
                        belt = beltOptions.first ?? ""
                    }
                }
            } else {
                Menu {
                    ForEach(beltOptions, id: \.self) { beltOption in
                        Button(action: {
                            self.belt = beltOption
                        }) {
                            Text(beltOption)
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
                .padding(.horizontal, 20)
            }
        }
    }
}

// Preview
struct CreateAccountView_Previews: PreviewProvider {
    @State static var selectedTabIndex = 0

    static var previews: some View {
        CreateAccountView(
            islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
            isUserProfileActive: .constant(true),
            persistenceController: PersistenceController.shared,
            selectedTabIndex: $selectedTabIndex,
            emailManager: UnifiedEmailManager.shared
        )
        .environmentObject(AuthenticationState())
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
