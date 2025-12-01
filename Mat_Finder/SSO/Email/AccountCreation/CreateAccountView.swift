//  CreateAccountView.swift
//  Mat_Finder
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


struct CreateAccountView: View {
    // Environment and Context
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext // Correctly named
    
    // Navigation and Routing
    @Binding var isUserProfileActive: Bool
    @State private var shouldNavigateToLogin = false
    
    // Form State and Validation
    @State private var formState: FormState = FormState()
    @State private var bypassValidation = false
    @State private var showValidationMessage = false
    
    // Form Validation Variables
    @State private var isIslandNameValid: Bool = true
    @State private var islandNameErrorMessage: String = ""
    @State private var isFormValid: Bool = false
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @StateObject var profileViewModel: ProfileViewModel
    @ObservedObject var countryService: CountryService
    
    // MARK: - Account & Address Info
    @State private var islandDetails = IslandDetails()
    @State private var selectedCountry: Country? = Country(name: Country.Name(common: "United States"), cca2: "US", flag: "")

    
    // Account and Profile Information
    @State private var belt: String = ""
    let beltOptions = ["", "White", "Blue", "Purple", "Brown", "Black"]
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?
    @State private var selectedProtocol = "http://"

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
    
    @Binding var navigationPath: NavigationPath // <- Use parent navigation
    
    @Binding var selectedTabIndex: LoginViewSelection
    
    
    let emailManager: UnifiedEmailManager
    
    init(
        islandViewModel: PirateIslandViewModel,
        isUserProfileActive: Binding<Bool>,
        selectedTabIndex: Binding<LoginViewSelection>,
        navigationPath: Binding<NavigationPath>,
        persistenceController: PersistenceController,
        countryService: CountryService = .shared,
        emailManager: UnifiedEmailManager
    ) {
        self._islandViewModel = ObservedObject(wrappedValue: islandViewModel)
        self._isUserProfileActive = isUserProfileActive
        self._selectedTabIndex = selectedTabIndex
        self._navigationPath = navigationPath
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

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
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
                        .foregroundColor(.primary)
                    Text("(Optional)")
                        .foregroundColor(.secondary)
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
                        islandDetails: $islandDetails,
                        selectedCountry: $selectedCountry,
                        gymWebsite: $islandDetails.gymWebsite,
                        gymWebsiteURL: $gymWebsiteURL,
                        
                        province: $islandDetails.province,
                        neighborhood: $islandDetails.neighborhood,
                        complement: $islandDetails.complement,
                        apartment: $islandDetails.apartment,
                        region: $islandDetails.region,
                        county: $islandDetails.county,
                        governorate: $islandDetails.governorate,
                        additionalInfo: $islandDetails.additionalInfo,
                        
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
                        
                        isIslandNameValid: $isIslandNameValid,
                        islandNameErrorMessage: $islandNameErrorMessage,
                        isFormValid: $isFormValid,
                        showAlert: $showAlert,
                        alertMessage: $alertMessage,
                        formState: $formState
                    )
                }
                
                // ✅ Always enabled "Create Account" button
                Button(action: {
                    Task {
                        let country = selectedCountry?.name.common ?? ""
                        let (isValid, errorMsg) = isValidForm()
                        
                        if isValid {
                            createAccount(country: country)
                        } else {
                            alertMessage = errorMsg ?? "Please complete all required fields."
                            showAlert = true
                        }
                    }
                }) {
                    Text("Create Account")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom)
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Incomplete Form"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .onAppear {
                    print("Island Name: '\(islandDetails.islandName)'")
                    print("Full Address: '\(islandDetails.fullAddress)'")
                    print("Form State - isUserNameValid: \(formState.isUserNameValid), isEmailValid: \(formState.isEmailValid)")
                    Task {
                        await countryService.fetchCountries()
                    }
                }
            }
            .padding(.vertical)
            .background(Color(uiColor: .systemBackground))
            .ignoresSafeArea()
            .onChange(of: selectedCountry) { newCountry, _ in
                islandDetails.selectedCountry = newCountry
                formState.selectedCountry = newCountry
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

        os_log("Debug: Starting form validation", type: .debug)

        print("Debug: Full Address456 = '\(islandDetails.fullAddress)'")

        logFormState()

        let (isValid, errorMessage) = isValidForm()
        if !isValid {
            os_log("Form is invalid. Validation failed.", type: .debug)
            self.errorMessage = errorMessage
            self.showValidationMessage = true
            isButtonDisabled = false
            return
        }

        os_log("Debug: All validations passed. Proceeding to create account.", type: .debug)

        Task { @MainActor in // Ensure UI updates are on MainActor
            do {
                if await AuthViewModel.shared.userAlreadyExists() {
                    os_log("User already exists. Aborting account creation.", type: .error)
                    self.errorMessage = "An account with this email already exists."
                    self.showValidationMessage = true
                    isButtonDisabled = false
                    return
                }

                try await AuthViewModel.shared.createUser(
                    withEmail: formState.email,
                    password: formState.password,
                    userName: formState.userName,
                    name: formState.name,
                    belt: belt
                )

                os_log("Account created successfully. Preparing to send verification emails...", type: .info)

                successMessage = "Account created successfully. You may now log in."
                showErrorAlert = true

                logAddressDetails()

                await createPirateIslandIfValid()

                handleSuccess()
            } catch {
                handleCreateAccountError(error)
            }
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

    /// Validates full Create Account form
    func isValidForm() -> (isValid: Bool, message: String?) {
        var _: String? = nil

        // --- Username ---
        if !formState.isUserNameValid {
            return (false, "Username is missing/invalid.")
        }

        // --- Name ---
        if !formState.isNameValid {
            return (false, "Full name is missing/invalid.")
        }

        // --- Email ---
        if !formState.isEmailValid {
            return (false, "Email address is missing/invalid.")
        }

        // --- Password ---
        if !formState.isPasswordValid {
            return (false, "Password is missing/invalid.")
        }

        // --- Confirm Password ---
        if formState.password != formState.confirmPassword {
            return (false, "Passwords do not match.")
        }

        // --- Address Required Only if Island Name NOT blank ---
        if !islandDetails.islandName.isEmpty {
            let countryCode = islandDetails.selectedCountry?.cca2 ?? ""

            if !isAddressValid(for: countryCode) {
                return (false, "Please complete all required address fields for the selected country.")
            }
        }


        // DEBUG LOGGING
        print("""
        Debug: Validation Status -
        Username Valid: \(formState.isUserNameValid)
        Name Valid: \(formState.isNameValid)
        Email Valid: \(formState.isEmailValid)
        Password Valid: \(formState.isPasswordValid)
        Passwords Match: \(formState.password == formState.confirmPassword)
        Address Valid (if required): \((formState.islandName.isEmpty || isAddressValid(for: formState.selectedCountry?.cca2 ?? "")))
        """)

        return (true, nil)
    }


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
                    //case .country: // This field is typically handled by a picker, not a text field for validation this way
                        //if selectedCountry == nil { return false }
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
        
        os_log("createPirateIslandIfValid islandName: %@", type: .info, islandDetails.islandName)
        os_log("createPirateIslandIfValid street: %@", type: .info, islandDetails.street)
        os_log("createPirateIslandIfValid city: %@", type: .info, islandDetails.city)
        os_log("createPirateIslandIfValid state: %@", type: .info, islandDetails.state)
        os_log("createPirateIslandIfValid postalCode: %@", type: .info, islandDetails.postalCode)
        os_log("createPirateIslandIfValid neighborhood: %@", type: .info, islandDetails.neighborhood)
        os_log("createPirateIslandIfValid complement: %@", type: .info, islandDetails.complement)
        os_log("createPirateIslandIfValid province: %@", type: .info, islandDetails.province)
        os_log("createPirateIslandIfValid region: %@", type: .info, islandDetails.region)
        os_log("createPirateIslandIfValid governorate: %@", type: .info, islandDetails.governorate)
        os_log("createPirateIslandIfValid selectedCountry: %@", type: .info, selectedCountry?.name.common ?? "nil")
        os_log("createPirateIslandIfValid createdByUserId: %@", type: .info, formState.userName)
        os_log("createPirateIslandIfValid gymWebsite: %@", type: .info, islandDetails.gymWebsite)
        
        let (isValid, errorMessage) = ValidationUtility.validateIslandForm(
            islandName: islandDetails.islandName,
            street: islandDetails.street,
            city: islandDetails.city,
            state: islandDetails.state,
            postalCode: islandDetails.postalCode,
            neighborhood: islandDetails.neighborhood,
            complement: islandDetails.complement,
            province: islandDetails.province,
            region: islandDetails.region,
            governorate: islandDetails.governorate,
            selectedCountry: selectedCountry,
            gymWebsite: islandDetails.gymWebsite
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

        guard let currentUser = await AuthViewModel.shared.getCurrentUser() else {
            toastMessage = "Error: No user logged in"
            showToast = true
            return
        }

        do {
            print("Creating pirate island...")

            let newIsland = try await islandViewModel.createPirateIsland(
                islandDetails: islandDetails,
                createdByUserId: currentUser.userName,
                gymWebsite: islandDetails.gymWebsite,
                country: selectedCountry.cca2,
                selectedCountry: selectedCountry,
                createdByUser: currentUser
            )

            print("Pirate island created: \(newIsland.islandName ?? "Unknown Name")")
            
            newIsland.country = islandDetails.selectedCountry?.name.common
            print("Country set: \(newIsland.country ?? "Unknown Country")")
            
            if !islandDetails.gymWebsite.isEmpty {
                print("Setting gym website URL...")
                if let url = URL(string: islandDetails.gymWebsite) {
                    newIsland.gymWebsite = url
                    print("Gym website URL set: \(url.absoluteString)")
                } else {
                    print("Invalid gym website URL: \(islandDetails.gymWebsite)")
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

        // Ensure this method exists and works as expected
        resetAuthenticationState()
    }
    
    /// Handles successful account creation.
    private func handleSuccess() {
        os_log("Account created successfully...", type: .info)
        
        // Send verification email
        sendVerificationEmails()
        
        // Show success alert briefly, then navigate
        showErrorAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showErrorAlert = false
            // Navigate to IslandMenu2 (or the first screen in your app)
            navigationPath.append(AppScreen.allLocations)
            authenticationState.isAuthenticated = true
        }

        // Optional: reset form or other state if needed
        // resetAuthenticationState() // Remove if you don't want to wipe auth state
    }



    private func sendVerificationEmails() {
        let email = formState.email

        Task {
            // --- Firebase email verification (still using completion handler) ---
            UnifiedEmailManager.shared.sendEmailVerification(to: email) { success in
                if success {
                    os_log("Firebase email verification sent: Passed", type: .info)
                    print("Firebase email verification sent: Passed")
                } else {
                    // If the completion handler *could* pass an Error, you'd handle it here.
                    // For now, we only know 'success' or 'failure'.
                    os_log("Firebase email verification sent: Failed", type: .error) // Log as error if failed
                    print("Firebase email verification sent: Failed")
                    // Potentially show an alert to the user that this specific email failed
                }
            }
        
            // --- Custom verification token email temporarily disabled ---
            print("Custom verification token email sending disabled (server-side issue)")
            os_log("Custom verification token email sending disabled", type: .info)

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
            case .fieldMissing(let fieldName):
                return "\(fieldName) is missing." // More specific
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
