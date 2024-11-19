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
                        let validationMessage = ValidationUtility.validateField(password, type: .password)
                        return validationMessage?.rawValue ?? ""
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
                        gymWebsite: $gymWebsite,
                        gymWebsiteURL: $gymWebsiteURL,
                        selectedCountry: $selectedCountry,
                        showAlert: .constant(false),
                        alertMessage: .constant(""),
                        islandDetails: $islandDetails // Corrected line
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

        // Start an asynchronous task
        Task {
            do {
                // Create the user account
                try await authViewModel.createUser(
                    withEmail: formState.email,
                    password: formState.password,
                    userName: formState.userName,
                    name: formState.name
                )
                successMessage = "Account created successfully"
                showErrorAlert = true

                // Construct the location string
                let location = "\(street), \(city), \(state) \(zip)".trimmingCharacters(in: .whitespacesAndNewlines)

                // Prepare for creating the Pirate Island, only if name and location are not empty
                if !islandName.isEmpty && !location.isEmpty {
                    // Attempt to create the Pirate Island asynchronously
                    let result = await islandViewModel.createPirateIslandAsync(
                        islandDetails: islandDetails,
                        createdByUserId: formState.userName,
                        gymWebsiteURL: gymWebsiteURL
                    )

                    // Handle the result of creating the Pirate Island
                    switch result {
                    case .success(let newIsland):
                        // Update coordinates for the new island
                        await self.updateIslandCoordinates(newIsland, location)  // Now it's valid to use 'await'
                    case .failure(let error):
                        // Handle the failure case when creating the Pirate Island
                        print("Error creating pirate island: \(error.localizedDescription)")
                    }
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
            let coordinates = try await geocode(address: location, apiKey: GeocodingConfig.apiKey)
            
            // Call the method to update latitude/longitude with the fetched coordinates
            // Ensure this method is async so that it can be awaited without the completion handler
            try await self.islandViewModel.updatePirateIslandLatitudeLongitude(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                island: island
            )
            
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
            case .geocodingError:
                return "Geocoding error"
            case .savingError:
                return "Saving error"
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
            selectedTabIndex: $selectedTabIndex
        )
        .environmentObject(AuthenticationState())
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
