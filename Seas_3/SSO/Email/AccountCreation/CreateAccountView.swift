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

enum CreateAccountError: Int {
    case invalidEmailOrPassword = 17011
    case userNotFound = 17008
    case missingPermissions = 7
    case emailAlreadyInUse = 17007
}

// Ensure `FormFieldViews.swift` is accessible
struct CreateAccountView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Binding var isUserProfileActive: Bool
    @State private var formState: FormState = FormState()
    @State private var belt: String = ""
    @State private var bypassValidation = false
    @StateObject var authViewModel = AuthViewModel()
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var shouldNavigateToLogin = false
    @Binding var selectedTabIndex: Int
    @State private var showValidationMessage = false

    let beltOptions = ["White", "Blue", "Purple", "Brown", "Black"]
    @State private var neighborhood: String = ""
    @State private var complement: String = ""
    @State private var apartment: String = ""
    @State private var additionalInfo: String = ""
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @StateObject var profileViewModel: ProfileViewModel

    @State private var islandName = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?
    @State private var selectedProtocol = "http://"
    @State private var showLoginReset = false
    @State private var province = ""
    @State private var postalCode = ""
    @State private var selectedCountry: Country? = Country(name: Country.Name(common: "United States"), cca2: "US")
    @State private var governorate = ""
    @State private var postcode = ""
    @State private var countries: [Country] = []
    @State private var region = ""
    @State private var county = ""
    @State private var islandDetails = IslandDetails()

    let emailManager: UnifiedEmailManager

    init(
        islandViewModel: PirateIslandViewModel,
        isUserProfileActive: Binding<Bool>,
        persistenceController: PersistenceController,
        selectedTabIndex: Binding<Int>,
        emailManager: UnifiedEmailManager = .shared
    ) {
        self._islandViewModel = ObservedObject(wrappedValue: islandViewModel)
        self._isUserProfileActive = isUserProfileActive
        self._selectedTabIndex = selectedTabIndex
        self.emailManager = emailManager
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(viewContext: persistenceController.container.viewContext))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
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
                
                BeltSection(belt: $belt)
                
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
                        province: $province,
                        postalCode: $postalCode,
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
                    
                    if let country = selectedCountry,
                       let format = countryAddressFormats.first(where: { $0.key == country.name.common })?.value {
                        
                        // Unwrap requiredFields directly (if it’s non-optional)
                        let requiredFields = format.requiredFields

                        // Address fields
                        ForEach(requiredFields, id: \.self) { field in
                            Text("Rendering field: \(field.rawValue)") // Display field name as part of the UI for debugging
                                .onAppear {
                                    print("Rendering field: \(field.rawValue)") // Debug print when the field appears
                                }
                            addressField(for: field)
                        }
                        
                        // Validation message
                        if showValidationMessage {
                            Text("Required fields for \(country.name.common) are missing.")
                                .foregroundColor(.red)
                        }
                    }
                }
                

                Button(action: createAccount) {
                    Text("Create Account")
                        .font(.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            formState.isUserNameValid &&
                            formState.isNameValid &&
                            formState.isEmailValid &&
                            formState.isPasswordValid &&
                            formState.isConfirmPasswordValid &&
                            errorMessage == nil ? Color.blue : Color.gray
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .opacity(
                    formState.isUserNameValid &&
                    formState.isNameValid &&
                    formState.isEmailValid &&
                    formState.isPasswordValid &&
                    formState.isConfirmPasswordValid &&
                    errorMessage == nil ? 1 : 0.5
                )
                .disabled(
                    !(formState.isUserNameValid &&
                    formState.isNameValid &&
                    formState.isEmailValid &&
                    formState.isPasswordValid &&
                    formState.isConfirmPasswordValid) || errorMessage != nil
                )
                .padding(.bottom)
            }
            .padding(.horizontal, 24)
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

    @ViewBuilder
    func addressField(for field: AddressField) -> some View {
        let binding = AddressBindingHelper.binding(for: field, islandDetails: $islandDetails)
        
        switch field {
        case .street:
            TextField("Enter street", text: binding)
        case .city:
            TextField("Enter city", text: binding)
        case .zip:
            TextField("Enter zip code", text: binding)
        case .postalCode:
            TextField("Enter postal code", text: binding)
        case .county:
            TextField("Enter county", text: binding)
        case .country:
            if let country = selectedCountry {
                TextField("Enter country", text: Binding(
                    get: { country.name.common },
                    set: { newValue in
                        selectedCountry = Country(name: Country.Name(common: newValue), cca2: country.cca2)
                    }
                ))
            } else {
                TextField("Enter country", text: Binding(
                    get: { "" },
                    set: { newValue in
                        // Handle initialization logic
                    }
                ))
            }
        case .governorate:
            TextField("Enter governorate", text: binding)
        case .postcode:
            TextField("Enter postcode", text: binding)
        case .region:
            TextField("Enter region", text: binding)
        default:
            EmptyView() // Handle unexpected cases
        }
    }

    private func createAccount() {
        print("Create Account button pressed.")
        print("Current form state: \(formState)")
        print("Validation Check:")
        print("Username Valid: \(formState.isUserNameValid)")
        print("Name Valid: \(formState.isNameValid)")
        print("Email Valid: \(formState.isEmailValid)")
        print("Password Valid: \(formState.isPasswordValid)")

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
                successMessage = "Account created successfully"
                showErrorAlert = true

                // Update individual address fields in islandDetails
                islandDetails.islandName = islandName
                islandDetails.street = street
                islandDetails.city = city
                islandDetails.state = state
                islandDetails.zip = zip
                islandDetails.country = selectedCountry?.name.common ?? ""

                // Use fullAddress indirectly through its computed value after fields are set
                let location = islandDetails.fullAddress

                if !islandName.isEmpty && !location.isEmpty {
                    Logger.logCreatedByIdEvent(
                        createdByUserId: formState.userName,
                        fileName: "CreateAccountView",
                        functionName: "createPirateIsland"
                    )
                    let newIsland = try await islandViewModel.createPirateIsland(
                        islandDetails: islandDetails,
                        createdByUserId: formState.userName
                    )

                    print("Pirate island created successfully: \(newIsland.islandName ?? "Unknown")")
                }

                // Handle overall success (e.g., show a success message or navigate to another view)
                handleSuccess()

            } catch {
                // Handle any errors that occurred during the account creation process
                print("Create account error: \(error.localizedDescription)")
                handleCreateAccountError(error)
            }
        }
    }

    private func updateIslandCoordinates(_ island: PirateIsland, _ location: String) async {
        do {
            try GeocodingConfig.validateApiKey()
            let coordinates = try await islandViewModel.geocodeAddress(location)
            island.latitude = coordinates.latitude
            island.longitude = coordinates.longitude
            try await PersistenceController.shared.saveContext()
            print("Latitude/Longitude updated successfully")
        } catch {
            print("Error updating latitude/longitude: \(error.localizedDescription)")
            // Handle geocoding or saving error
        }
    }


    /// Handles successful account creation.
    private func handleSuccess() {
        print("Account created successfully. Preparing to send verification emails...")

        // Send Firebase email verification
        let email = formState.email
        UnifiedEmailManager.shared.sendEmailVerification(to: email) { success in
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
        }

        successMessage = "Account created successfully. Check your email for login instructions."
        showErrorAlert = true

        // Reset authentication state
        authenticationState.isAuthenticated = false
        authenticationState.isLoggedIn = false

        // Navigate back to login
        isUserProfileActive = false
    }

    /// Handles create account errors, including existing user error.
    func handleCreateAccountError(_ error: Error) {
        errorMessage = getErrorMessage(error)
        showErrorAlert = true

        print("Create account error: \(errorMessage ?? "Unknown error")")

        // Reset authentication state
        authenticationState.isAuthenticated = false
        authenticationState.isLoggedIn = false
        authenticationState.navigateToAdminMenu = false

        isUserProfileActive = false
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
            case .zipMissing:
                return "Zip code is missing"
            case .fieldMissing(_):
                return "Some OTHER field is missing"
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

    func getInvalidFields() -> String {
        var invalidFields = [String]()

        if !formState.isUserNameValid {
            invalidFields.append("Username")
        }

        if !formState.isNameValid {
            invalidFields.append("Name")
        }

        if !formState.isEmailValid {
            invalidFields.append("Email")
        }

        if !formState.isPasswordValid {
            invalidFields.append("Password")
        }

        return invalidFields.joined(separator: ", ")
    }
    
    struct BeltSection: View {
        @Binding var belt: String

        var body: some View {
            VStack(alignment: .leading) {
                Text("Belt")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Picker("Select your belt", selection: $belt) {
                    ForEach(["White", "Blue", "Purple", "Brown", "Black"], id: \.self) { belt in
                        Text(belt)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.bottom)
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
