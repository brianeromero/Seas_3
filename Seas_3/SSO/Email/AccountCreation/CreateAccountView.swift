//  CreateAccountView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import CoreData
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
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
    
    // Form Validation Variables
    @State private var isIslandNameValid: Bool = true
    @State private var islandNameErrorMessage: String = ""
    @State private var isFormValid: Bool = false
    
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
    @State private var selectedCountry: Country? = Country(name: Country.Name(common: "United States"), cca2: "US", flag: "") {
        didSet {
            islandDetails.selectedCountry = selectedCountry
        }
    }
    @State private var governorate = ""
    @State private var region = ""
    @State private var county = ""
    @State private var islandDetails = IslandDetails()
    @State private var block: String = ""
    @State private var district: String = ""
    @State private var department: String = ""
    @State private var emirate: String = ""
    @State private var parish: String = ""
    @State private var entity: String = ""
    @State private var municipality: String = ""
    @State private var division: String = ""
    @State private var zone: String = ""
    @State private var island: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var additionalInfo: String = ""
    @State private var neighborhood: String = ""
    @State private var complement: String = ""
    @State private var apartment: String = ""
    @State private var multilineAddress: String = ""
    @State private var requiredAddressFields: [AddressFieldType] = []
    @State private var country: String = ""
    
    // Alerts and Toasts
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    // Picker and Modal States
    @State private var isPickerPresented = false
    @State private var countries: [Country] = []
    
    @State private var isButtonDisabled = false
    @State private var localIsLoggedIn = false

    
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
 
    // Validation logic
    var isIslandNameRequired: Bool {
        let isRequired = islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty
        os_log("Computed property accessed: isIslandNameRequired = %@", type: .debug, isRequired ? "Yes" : "No")
        return isRequired
    }

    var areAddressFieldsRequired: Bool {
        let isRequired = isIslandNameRequired && !ValidationUtility.validateIslandForm(
            islandName: islandDetails.islandName,
            street: islandDetails.street,
            city: islandDetails.city,
            state: islandDetails.state,
            postalCode: islandDetails.postalCode,
            selectedCountry: selectedCountry,
            gymWebsite: islandDetails.gymWebsite
        ).isValid

        os_log("Computed property accessed: areAddressFieldsRequired = %@", type: .debug, isRequired ? "Yes" : "No")
        return isRequired
    }


    var addressFormIsValid: Bool {
        if islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty {
            os_log("Island name is empty, returning false for address form validation.", type: .debug)
            return false // Island name is required, so return false if empty
        } else {
            // Validate using validateIslandForm and return isValid
            let validation = ValidationUtility.validateIslandForm(
                islandName: islandDetails.islandName,
                street: islandDetails.street,
                city: islandDetails.city,
                state: islandDetails.state,
                postalCode: islandDetails.postalCode,
                selectedCountry: selectedCountry,
                gymWebsite: islandDetails.gymWebsite
            )
            os_log("Validation result for address fields: %@", type: .debug, validation.isValid ? "Valid" : "Invalid")
            return validation.isValid
        }
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
                
                BeltSection(belt: $belt, beltOptions: beltOptions, usePickerStyle: true)

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
                            profileViewModel: profileViewModel,
                            countryService: countryService,
                            islandName: $islandDetails.islandName,
                            street: $islandDetails.street,
                            city: $islandDetails.city,
                            state: $islandDetails.state,
                            postalCode: $islandDetails.postalCode,
                            islandDetails: $islandDetails,  // Keep islandDetails in the correct position
                            selectedCountry: $selectedCountry,
                            gymWebsite: $islandDetails.gymWebsite,
                            gymWebsiteURL: $gymWebsiteURL,
                            
                            // Correct order:
                            province: $province,
                            neighborhood: $neighborhood,
                            complement: $complement,
                            apartment: $apartment,
                            region: $region,
                            county: $county,
                            governorate: $governorate,
                            additionalInfo: $additionalInfo,

                            // Add the new fields:
                            department: $islandDetails.department,
                            parish: $islandDetails.parish,
                            district: $islandDetails.district,
                            entity: $islandDetails.entity,
                            municipality: $islandDetails.municipality,
                            division: $islandDetails.division,
                            emirate: $islandDetails.emirate,
                            zone: $islandDetails.zone,
                            block: $islandDetails.block,
                            island: $islandDetails.island,

                            // Validation and alert:
                            isIslandNameValid: $isIslandNameValid,
                            islandNameErrorMessage: $islandNameErrorMessage,
                            isFormValid: $isFormValid,
                            showAlert: $showAlert,
                            alertMessage: $alertMessage,
                            formState: $formState
                        )
                    }

                
                Button(action: {
                    // Display values before validation to confirm they are correctly populated
                    print("Island Name: '\(islandDetails.islandName)'")
                    print("Street: '\(islandDetails.street)'")
                    print("City: '\(islandDetails.city)'")
                    
                    // Start by disabling the button
                    print("Button tapped - isButtonDisabled: \(isButtonDisabled)")
                    if isButtonDisabled {
                        return // Don't proceed if the button is disabled
                    }

                    // Disable the button to prevent multiple taps
                    isButtonDisabled = true
                    
                    // Call the task to validate the form and create the account
                    Task {
                        debugPrint("Create Account Button tapped - validating form")
                        
                        if let countryCode = selectedCountry?.cca2 {
                            let normalizedCountryCode = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                            print("Normalized Country Code before validation: \(normalizedCountryCode)")
                            
                            do {
                                let addressFields = try getAddressFields(for: selectedCountry?.cca2 ?? "")
                                print("Address Fields Required: \(addressFields)")
                            } catch {
                                print("Error fetching address fields: \(error)")
                            }
                        }
                        
                        // Update country with the selected country's name
                        let country = selectedCountry?.name.common ?? ""
                        
                        // Use the updated isValidForm function
                        let (isValid, errorMessage) = isValidForm()
                        if isValid {
                            // Call createAccount with the updated country
                            createAccount(country: country)
                        } else {
                            debugPrint("Form is invalid")
                            self.errorMessage = errorMessage
                            self.showValidationMessage = true
                        }
                        
                        // When the process finishes (either success or failure), enable the button again
                        isButtonDisabled = false
                    }
                }) {
                    Text("Create Account")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isButtonDisabled || !isValidForm().isValid ? Color.gray : Color.blue) // Reflect form validity & disabled state
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .scaleEffect(isButtonDisabled ? 1.0 : 0.98) // Add subtle scale effect when button is pressed
                        .shadow(radius: isButtonDisabled ? 0 : 5) // Shadow effect to make the button look like it's raised
                        .opacity(isButtonDisabled || !isValidForm().isValid ? 0.5 : 1) // Adjust opacity based on button state
                }
                .disabled(isButtonDisabled || !isValidForm().isValid) // Disable the button if already disabled or form is invalid
                .padding(.bottom)
                .padding(.horizontal, 24)
                .onAppear {
                    print("Island Name: '\(islandDetails.islandName)'")
                    print("Full Address: '\(islandDetails.fullAddress)'")
                    print("Form State - isUserNameValid: \(formState.isUserNameValid), isEmailValid: \(formState.isEmailValid)")
                    print("Debug: Initial state - islandName: '\(islandDetails.islandName)', fullAddress: '\(islandDetails.fullAddress)', email: '\(formState.email)', username: '\(formState.userName)'")

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
                            successMessage = nil
                            errorMessage = nil

                            // Set authentication flags using Task to safely call async MainActor methods
                            Task {
                                authenticationState.reset()
                            }
                        }
                    )
                }

                .navigationDestination(isPresented: $shouldNavigateToLogin) {
                    LoginView(
                        islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                        profileViewModel: profileViewModel,
                        isSelected: .constant(LoginViewSelection(rawValue: selectedTabIndex) ?? .login),
                        navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                        isLoggedIn: $localIsLoggedIn
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
                get: { selectedCountry?.name.common ?? "" },
                set: { newValue in
                    if let currentCountry = selectedCountry {
                        self.selectedCountry = Country(
                            name: Country.Name(common: newValue),
                            cca2: currentCountry.cca2,
                            flag: currentCountry.flag
                        )
                    }
                }
            ))
        default:
            EmptyView()
        }
    }
    
    private func createAccount(country: String) {
        os_log("Calling createAccount", type: .info)

        // Start form validation
        os_log("Debug: Starting form validation", type: .debug)

        print("Debug: Full Address456 = '\(islandDetails.fullAddress)'")

        logFormState()

        // Check if form is valid
        let (isValid, errorMessage) = isValidForm()
        if !isValid {
            os_log("Form is invalid. Validation failed.", type: .debug)
            self.errorMessage = errorMessage
            self.showValidationMessage = true
            isButtonDisabled = false  // Ensure button is re-enabled on failure
            return
        }

        os_log("Debug: All validations passed. Proceeding to create account.", type: .debug)

        Task {
            do {
                // Check if user already exists
                if await authViewModel.userAlreadyExists() {
                    os_log("User already exists. Aborting account creation.", type: .error)
                    self.errorMessage = "An account with this email already exists."
                    self.showValidationMessage = true
                    isButtonDisabled = false
                    return
                }

                // Attempt to create the user account
                try await authViewModel.createUser(
                    withEmail: formState.email,
                    password: formState.password,
                    userName: formState.userName,
                    name: formState.name,
                    belt: belt
                )

                os_log("Account created successfully. Preparing to send verification emails...", type: .info)

                successMessage = "Account created successfully"
                showErrorAlert = true

                logAddressDetails()

                await createPirateIslandIfValid()

                handleSuccess()
            } catch {
                handleCreateAccountError(error)
            }

            // Re-enable the button after everything is complete
            isButtonDisabled = false
        }
    }

    // MARK: - Helper Functions

    private func logFormState() {
        os_log("Debug: Form state validation - %@", type: .debug, "\(formState)")
        os_log("Debug: Username Valid: %d, Name Valid: %d, Email Valid: %d, Password Valid: %d",
               type: .debug, formState.isUserNameValid, formState.isNameValid, formState.isEmailValid, formState.isPasswordValid)
    }

    private func logAddressDetails() {
        os_log("Debug: Full Address before validation: %@", type: .debug, islandDetails.fullAddress)
        os_log("islandName: %@", type: .info, islandDetails.islandName)
        os_log("Full Address789: %@", type: .info, islandDetails.fullAddress)
        print("Debug: Full Address789 = '\(islandDetails.fullAddress)'")
        os_log("Debug: Selected Country before validation: %@", type: .debug, selectedCountry?.name.common ?? "None")
    }

    func isValidForm() -> (isValid: Bool, errorMessage: String?) {
        var errorMessage: String?

        // Email Validation
        guard formState.isEmailValid else {
            errorMessage = "Please enter a valid email address."
            return (false, errorMessage)
        }

        // Name Validation
        guard !formState.name.isEmpty else {
            errorMessage = "Name is required."
            return (false, errorMessage)
        }

        // Address Validation (only if islandName is not blank)
        if !formState.islandName.isEmpty {
            guard let selectedCountry = formState.selectedCountry,
                  !selectedCountry.cca2.isEmpty else {
                errorMessage = "Please select a valid country."
                return (false, errorMessage)
            }

            if !isAddressValid(for: selectedCountry.cca2) {
                errorMessage = "Please fill in all required address fields."
                return (false, errorMessage)
            }
        }

        // Password Validation
        if !formState.isPasswordValid {
            errorMessage = "Password is invalid."
            return (false, errorMessage)
        }

        // Confirm Password Validation: Ensure passwords match
        if formState.password != formState.confirmPassword {
            errorMessage = "Confirm password doesn't match the password."
            return (false, errorMessage)
        }

        // Debug logging for detailed validation statuses
        print("""
        Debug: Validation Status -
        Username Valid: \(formState.isUserNameValid),
        Name Valid: \(formState.isNameValid),
        Email Valid: \(formState.isEmailValid),
        Password Valid: \(formState.isPasswordValid),
        Confirm Password Match: \(formState.password == formState.confirmPassword),
        Address Valid: \(isAddressValid(for: formState.selectedCountry?.cca2 ?? "")),
        Error Message: \(String(describing: errorMessage))
        """)

        return (formState.isPasswordValid && formState.password == formState.confirmPassword && (formState.islandName.isEmpty || isAddressValid(for: formState.selectedCountry?.cca2 ?? "")), nil)
    }



    // Address Validation Logic
    func isAddressValid(for countryCode: String) -> Bool {
        let normalizedCode = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCode.isEmpty else {
            print("Error in isAddressValid(for:): Country code is empty")
            return false
        }

        do {
            let requiredFields = try getAddressFields(for: normalizedCode)
            for field in requiredFields {
                switch field {
                    case .street: if islandDetails.street.isEmpty { return false }
                    case .city: if islandDetails.city.isEmpty { return false }
                    case .state: if islandDetails.state.isEmpty { return false }
                    case .province: if islandDetails.province.isEmpty { return false }
                    case .postalCode: if islandDetails.postalCode.isEmpty { return false }
                    case .region: if islandDetails.region.isEmpty { return false }
                    case .district: if islandDetails.district.isEmpty { return false }
                    case .department: if islandDetails.department.isEmpty { return false }
                    case .governorate: if islandDetails.governorate.isEmpty { return false }
                    case .emirate: if islandDetails.emirate.isEmpty { return false }
                    case .block: if islandDetails.block.isEmpty { return false }
                    case .county: if islandDetails.county.isEmpty { return false }
                    case .neighborhood: if islandDetails.neighborhood.isEmpty { return false }
                    case .complement: if islandDetails.complement.isEmpty { return false }
                    case .apartment: if islandDetails.apartment.isEmpty { return false }
                    case .additionalInfo: if islandDetails.additionalInfo.isEmpty { return false }
                    case .multilineAddress: if islandDetails.multilineAddress.isEmpty { return false }
                    case .parish: if islandDetails.parish.isEmpty { return false }
                    case .entity: if islandDetails.entity.isEmpty { return false }
                    case .municipality: if islandDetails.municipality.isEmpty { return false }
                    case .division: if islandDetails.division.isEmpty { return false }
                    case .zone: if islandDetails.zone.isEmpty { return false }
                    case .island: if islandDetails.island.isEmpty { return false }
                }
            }
            return true
        } catch {
            print("Error in isAddressValid(for:): \(error)")
            return false
        }
    }





    private func createPirateIslandIfValid() async {
        os_log("Debug: Validating island form...", type: .debug)
        
        // Logging inputs
        os_log("createPirateIslandIfValid islandName: %@", type: .info, islandDetails.islandName)
        os_log("createPirateIslandIfValid street: %@", type: .info, islandDetails.street)
        os_log("createPirateIslandIfValid city: %@", type: .info, islandDetails.city)
        os_log("createPirateIslandIfValid state: %@", type: .info, islandDetails.state)
        os_log("createPirateIslandIfValid postalCode: %@", type: .info, islandDetails.postalCode)
        os_log("createPirateIslandIfValid neighborhood: %@", type: .info, neighborhood)
        os_log("createPirateIslandIfValid complement: %@", type: .info, complement)
        os_log("createPirateIslandIfValid province: %@", type: .info, province)
        os_log("createPirateIslandIfValid region: %@", type: .info, region)
        os_log("createPirateIslandIfValid governorate: %@", type: .info, governorate)
        os_log("createPirateIslandIfValid selectedCountry: %@", type: .info, selectedCountry?.name.common ?? "nil")
        os_log("createPirateIslandIfValid createdByUserId: %@", type: .info, formState.userName)
        os_log("createPirateIslandIfValid gymWebsite: %@", type: .info, gymWebsite)
        
        // Form validation
        let (isValid, errorMessage) = ValidationUtility.validateIslandForm(
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
            gymWebsite: gymWebsite
        )
        
        os_log("Debug: Island validation result - isValid: %@, errorMessage: %@", type: .debug, isValid ? "Passed" : "Failed", errorMessage)
        
        guard isValid else {
            toastMessage = errorMessage
            showToast = true
            return
        }

        guard let selectedCountry = selectedCountry else {
            toastMessage = "Error: No country selected"
            showToast = true
            return
        }

        // ✅ Await the current user
        guard let currentUser = await authViewModel.getCurrentUser() else {
            toastMessage = "Error: No user logged in"
            showToast = true
            return
        }

        _ = currentUser.userName

        do {
            print("Creating pirate island...")

            let newIsland = try await islandViewModel.createPirateIsland(
                islandDetails: islandDetails,
                createdByUserId: currentUser.userName,
                gymWebsite: gymWebsite,
                country: selectedCountry.cca2,
                selectedCountry: selectedCountry,
                createdByUser: currentUser // ✅ Pass the currentUser directly
            )

            print("Pirate island created: \(newIsland.islandName ?? "Unknown Name")")
            
            newIsland.country = islandDetails.selectedCountry?.name.common
            print("Country set: \(newIsland.country ?? "Unknown Country")")
            
            if !gymWebsite.isEmpty {
                print("Setting gym website URL...")
                if let url = URL(string: gymWebsite) {
                    newIsland.gymWebsite = url
                    print("Gym website URL set: \(url.absoluteString)")
                } else {
                    print("Invalid gym website URL: \(gymWebsite)")
                    toastMessage = "Invalid gym website URL"
                    showToast = true
                    return
                }
            }

            toastMessage = "Island saved successfully: \(newIsland.islandName ?? "Unknown Name")"
            print("Island saved successfully")
        } catch {
            print("Error creating pirate island: \(error.localizedDescription)")
            if let error = error as? PirateIslandError {
                toastMessage = "Error saving island: \(error.localizedDescription)"
            } else {
                toastMessage = getErrorMessage(error)
            }
            showToast = true
        }
    }



    
    private func handleCreateAccountError(_ error: Error) {
        os_log("Create account error occurred: %@", type: .error, error.localizedDescription)
        errorMessage = getErrorMessage(error)
        showErrorAlert = true

        print("Create account error: \(errorMessage ?? "An unknown error occurred.")")
        os_log("Debug: Error details: %@", type: .debug, error.localizedDescription)


        resetAuthenticationState()
    }

    
    /// Handles successful account creation.
    private func handleSuccess() {
        os_log("Account created successfully. Preparing to send verification emails456...", type: .info)

        sendVerificationEmails()
        successMessage = "Account created successfully. Check your email for login instructions."
        showErrorAlert = true
        resetAuthenticationState()
    }

    private func sendVerificationEmails() {
        let email = formState.email

        // Send Firebase email verification
        UnifiedEmailManager.shared.sendEmailVerification(to: email) { success in
            os_log("Firebase email verification sent: %@", type: .info, success ? "Passed" : "Failed")
            print("Firebase email verification sent: \(success ? "Passed" : "Failed")")
        }

        // Send custom verification token email
        Task {
            let success = await UnifiedEmailManager.shared.sendVerificationToken(
                to: email,
                userName: formState.userName,
                password: formState.password
            )
            print("Custom verification token email sent: \(success ? "Passed" : "Failed")")
            os_log("Custom verification token email sent: %@", type: .info, success ? "Passed" : "Failed")
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
        authenticationState.reset()
        isUserProfileActive = false
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
        .environmentObject(AuthenticationState(hashPassword: HashPassword()))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
