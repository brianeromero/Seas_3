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
    @State private var selectedCountry: Country? = Country(name: Country.Name(common: "United States"), cca2: "US", flag: "")
    @State private var governorate = ""
    @State private var region = ""
    @State private var county = ""
    @State private var islandName: String = ""
    @State private var street: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var postalCode: String = ""
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
        return !islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var areAddressFieldsRequired: Bool {
        return isIslandNameRequired && !areAddressFieldsValid(for: selectedCountry?.cca2 ?? "", islandDetails: islandDetails)
    }

    var addressFormIsValid: Bool {
        if islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        } else {
            return areAddressFieldsValid(for: selectedCountry?.cca2 ?? "", islandDetails: islandDetails)
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
                            province: $province,
                            neighborhood: $neighborhood,
                            complement: $complement,
                            apartment: $apartment,
                            region: $region,
                            county: $county,
                            governorate: $governorate,
                            additionalInfo: $additionalInfo,
                            islandDetails: $islandDetails, // Corrected order
                            selectedCountry: $selectedCountry,
                            showAlert: $showAlert,
                            alertMessage: $alertMessage,
                            gymWebsite: $islandDetails.gymWebsite,
                            gymWebsiteURL: $gymWebsiteURL,
                            isIslandNameValid: $isIslandNameValid,
                            islandNameErrorMessage: $islandNameErrorMessage,
                            isFormValid: $isFormValid,
                            formState: $formState
                        )
                    }
                

                // Error Message for Island Name and Address Validation
                // Validation Messages in ViewBuilder-friendly structure
                if isIslandNameRequired {
                    Text("Island name is required789.")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 20)
                }
                
                if areAddressFieldsRequired {
                    Text("Please fill in all required address fields123.")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 20)
                }




                
                Button(action: {
                    debugPrint("Create Account Button tapped - validating form")
                    
                    if let countryCode = selectedCountry?.cca2 {
                        let normalizedCountryCode = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        print("Normalized Country Code before validation: \(normalizedCountryCode)")
                        
                        do {
                            let addressFields = try getAddressFields(for: selectedCountry?.cca2 ?? "")
                            print("Address Fields Required: \(addressFields)")
                        } catch {
                            print("Error fetching address fields456: \(error)")
                        }
                    }
                    
                    // Use the updated isValidForm function
                    let (isValid, errorMessage) = isValidForm()
                    if isValid {
                        // Call createAccount only if the form is valid
                        createAccount()
                    } else {
                        debugPrint("Form is invalid123")
                        print("Form is invalid345")
                        self.errorMessage = errorMessage
                        self.showValidationMessage = true
                    }
                }) {
                    Text("Create Account")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidForm().isValid ? Color.blue : Color.gray) // Reflect form validity
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!isValidForm().isValid) // Disable the button if the form is invalid
                .opacity(isValidForm().isValid ? 1 : 0.5)
                .padding(.bottom)
                .padding(.horizontal, 24)


                .onAppear {
                    print("Island Name: '\(islandDetails.islandName)'")
                    print("Full Address123: '\(islandDetails.fullAddress)'")
                    print("Form State - isUserNameValid: \(formState.isUserNameValid), isEmailValid: \(formState.isEmailValid)")
                    print("Debug: Full Address123 = '\(islandDetails.fullAddress)'")
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
            // Directly bind to selectedCountry's common name
            TextField("Enter country", text: Binding(
                get: { islandDetails.selectedCountry?.name.common ?? "" },
                set: { newValue in
                    // Ensure you're updating islandDetails.selectedCountry correctly
                    if let currentCountry = islandDetails.selectedCountry {
                        islandDetails.selectedCountry = Country(
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

    
    func areAddressFieldsValid(for countryCode: String, islandDetails: IslandDetails) -> Bool {
        do {
            let requiredFields = try getAddressFields(for: countryCode)
            for field in requiredFields {
                // Dynamically check each required address field based on its keyPath
                let keyPath = AddressField(rawValue: field.rawValue)?.keyPath ?? \.street
                let value = islandDetails[keyPath: keyPath].trimmingCharacters(in: .whitespaces)
                print("Debug: Address field123'\(field.rawValue)' = '\(value)'")

                if value.isEmpty {
                    print("Debug: Address field456 '\(field.rawValue)' is missing.")
                    return false
                }
            }
            return true
        } catch {
            print("Error: \(error)")
            return false
        }
    }

    
    private func createAccount() {
        os_log("Create Account  button pressed - calling createAccount", type: .info)
        
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
            return
        }

        os_log("Debug: All validations passed. Proceeding to create account.", type: .debug)

        // Proceed with creating the account
        if userAlreadyExists() {
            return
        }

        Task {
            do {
                // Attempt to create the user account
                try await authViewModel.createUser(
                    withEmail: formState.email,
                    password: formState.password,
                    userName: formState.userName,
                    name: formState.name,
                    belt: belt
                )

                // If successful
                os_log("Account created successfully. Preparing to send verification emails...", type: .info)
            
                successMessage = "Account created successfully"
                showErrorAlert = true

                // Log address details and update fields
                logAddressDetails()
                updateIslandDetails()

                // Create Pirate Island if valid
                await createPirateIslandIfValid()

                // Handle overall success
                handleSuccess()
            } catch {
                // Handle any errors that occurred during the account creation process
                handleCreateAccountError(error)
            }
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

    private func updateIslandDetails() {
        islandDetails.islandName = islandName
        islandDetails.street = street
        islandDetails.city = city
        islandDetails.state = state
        islandDetails.postalCode = postalCode
        islandDetails.selectedCountry = selectedCountry
        islandDetails.country = country
        islandDetails.county = county
        islandDetails.gymWebsite = gymWebsite
        islandDetails.gymWebsiteURL = gymWebsiteURL
        islandDetails.neighborhood = neighborhood
        islandDetails.complement = complement
        islandDetails.block = block
        islandDetails.apartment = apartment
        islandDetails.region = region
        islandDetails.governorate = governorate
        islandDetails.province = province
        islandDetails.district = district
        islandDetails.department = department
        islandDetails.emirate = emirate
        islandDetails.parish = parish
        islandDetails.entity = entity
        islandDetails.municipality = municipality
        islandDetails.division = division
        islandDetails.zone = zone
        islandDetails.island = island
        islandDetails.additionalInfo = additionalInfo
        islandDetails.multilineAddress = multilineAddress
        islandDetails.requiredAddressFields = requiredAddressFields
    }

    func isValidForm() -> (isValid: Bool, errorMessage: String?) {
        var errorMessage: String?
        
        guard formState.isEmailValid else {
            errorMessage = "Please enter a valid email address."
            return (false, errorMessage)
        }
        
        guard !formState.name.isEmpty else {
            errorMessage = "Name is required."
            return (false, errorMessage)
        }
        
        if !addressFormIsValid {
            errorMessage = "Please fill in all required address fields456."
            return (false, errorMessage)
        }
        
        if !formState.isPasswordValid {
            errorMessage = "Password is invalid."
            return (false, errorMessage)
        }
        
        if !formState.isConfirmPasswordValid {
            errorMessage = "Confirm password doesn't match."
            return (false, errorMessage)
        }
        
        // Debug logging for detailed validation statuses
        print("""
        Debug: Validation Status -
            Username Valid: \(formState.isUserNameValid),
            Name Valid: \(formState.isNameValid),
            Email Valid: \(formState.isEmailValid),
            Password Valid: \(formState.isPasswordValid),
            Confirm Password Valid: \(formState.isConfirmPasswordValid),
            Address Valid: \(addressFormIsValid),
            Error Message: \(String(describing: errorMessage))
        """)
        
        return (addressFormIsValid && formState.isPasswordValid && formState.isConfirmPasswordValid, nil)
    }



    private func userAlreadyExists() -> Bool {
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@ OR userName == %@", formState.email, formState.userName)

        do {
            let existingUsers = try managedObjectContext.fetch(fetchRequest)
            if !existingUsers.isEmpty {
                if existingUsers.first?.email == formState.email {
                    errorMessage = "A user with this email address already exists."
                } else {
                    errorMessage = "A user with this username already exists."
                }
                showErrorAlert = true
                return true
            }
        } catch {
            handleCreateAccountError(error)
            return true
        }
        return false
    }

    private func createPirateIslandIfValid() async {
        os_log("Debug: Validating island form...", type: .debug)

        os_log("createPirateIslandIfValid islandName: %@", type: .info, islandDetails.islandName)
        os_log("createPirateIslandIfValid street: %@", type: .info, islandDetails.street)
        os_log("createPirateIslandIfValid city: %@", type: .info, islandDetails.city)
        os_log("createPirateIslandIfValid state: %@", type: .info, islandDetails.state)
        os_log("createPirateIslandIfValid postalCode: %@", type: .info, islandDetails.postalCode)
        os_log("createPirateIslandIfValid neighborhood: %@", type: .info, neighborhood)
        os_log("createPirateIslandIfValid complement: %@", type: .info, complement)
        os_log("createPirateIslandIfValid province: %@", type: .info, province)
        os_log("createPirateIslandIfValid region: %@", type: .info, region)
        os_log("createPirateIslandIfValid overnorate: %@", type: .info, governorate)
        os_log("createPirateIslandIfValid selectedCountry: %@", type: .info, selectedCountry?.name.common ?? "nil")
        os_log("createPirateIslandIfValid createdByUserId: %@", type: .info, formState.userName)
        os_log("createPirateIslandIfValid gymWebsite: %@", type: .info, gymWebsite)


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
        
        os_log("Debug: Island validation result - isValid: %d, errorMessage: %@", type: .debug, isValid, errorMessage)


        guard isValid else {
            self.errorMessage = errorMessage
            showErrorAlert = true
            return
        }

        if let urlError = ValidationUtility.validateURL(gymWebsite), !gymWebsite.isEmpty {
            errorMessage = "Invalid gym website URL: \(urlError)"
            showErrorAlert = true
            os_log("Invalid gym website URL", type: .error)
            return
        }

        if islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty {
            errorMessage = "Please provide a valid island name."
            showErrorAlert = true
            return
        }

        do {
            // Use islandDetails.selectedCountry?.cca2 directly
            let newIsland = try await islandViewModel.createPirateIsland(
                islandDetails: islandDetails,
                createdByUserId: profileViewModel.name,
                gymWebsite: gymWebsite,
                country: islandDetails.selectedCountry?.cca2 ?? "" // Directly access the country code here
            )

            // Store the country and gym website URL in the new island
            newIsland.country = islandDetails.selectedCountry?.name.common

            if !gymWebsite.isEmpty {
                if let url = URL(string: gymWebsite) {
                    newIsland.gymWebsite = url
                } else {
                    // Handle invalid URL
                    toastMessage = "Invalid gym website URL"
                    showToast = true
                    return
                }
            }

            toastMessage = "Island saved successfully: \(newIsland.islandName ?? "Unknown Name")"
         } catch {
            if let error = error as? PirateIslandError {
                toastMessage = "Error saving island: \(error.localizedDescription)"
                showToast = true
            } else {
                let errorMessage = getErrorMessage(error)
                toastMessage = errorMessage
                showToast = true
            }
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
