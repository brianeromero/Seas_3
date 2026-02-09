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
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.dismiss) private var dismiss
    
    
    // Navigation and Routing
    @Binding var isUserProfileActive: Bool
    @Binding var selectedTabIndex: LoginViewSelection
    @Binding var navigationPath: NavigationPath
    
    // Form State and Validation
    @State private var formState: FormState = FormState()
    @State private var bypassValidation = false
    @State private var isFormValid: Bool = false
    
    // Form Validation Variables
    @State private var isIslandNameValid: Bool = true
    @State private var islandNameErrorMessage: String = ""
    
    // Account & Address Info
    @State private var islandDetails = IslandDetails(
        selectedCountry: Country(name: Country.Name(common: "United States"), cca2: "US", flag: "")
    )


    // Account and Profile Information
    
    @State private var gymWebsite: String = ""
    @State private var gymWebsiteURL: URL? = nil
    @State private var isSaveEnabled: Bool = false
    
    @State private var showValidationMessage = false
    @State private var missingFields: [String] = []

    
    @State private var belt: String = ""
    let beltOptions = ["", "White", "Blue", "Purple", "Brown", "Black"]
    
    // Alerts
    @Binding var showAlert: Bool
    @Binding var alertTitle: String   // <-- NEW
    @Binding var alertMessage: String
    @Binding var currentAlertType: AccountAlertType?   // <-- new binding
    @Binding var showCreateAccount: Bool
    
    
    
    // Button State
    @State private var isButtonDisabled = false
    
    // Observed / StateObjects
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @StateObject var profileViewModel: ProfileViewModel
    @ObservedObject var countryService: CountryService
    
    
    
    let emailManager: UnifiedEmailManager
    

    // MARK: - Init
    init(
        islandViewModel: PirateIslandViewModel,
        isUserProfileActive: Binding<Bool>,
        selectedTabIndex: Binding<LoginViewSelection>,
        navigationPath: Binding<NavigationPath>,
        countryService: CountryService = .shared,
        emailManager: UnifiedEmailManager,
        showAlert: Binding<Bool>,
        alertTitle: Binding<String>,
        alertMessage: Binding<String>,
        currentAlertType: Binding<AccountAlertType?>,
        showCreateAccount: Binding<Bool>
    ) {
        self._islandViewModel = ObservedObject(wrappedValue: islandViewModel)
        self._isUserProfileActive = isUserProfileActive
        self._selectedTabIndex = selectedTabIndex
        self._navigationPath = navigationPath
        self.countryService = countryService
        self.emailManager = emailManager
        _profileViewModel = StateObject(wrappedValue: ProfileViewModel())
        self._showAlert = showAlert
        self._alertTitle = alertTitle
        self._alertMessage = alertMessage
        self._currentAlertType = currentAlertType
        self._showCreateAccount = showCreateAccount
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ← BACK BUTTON
                HStack {
                    Button(action: { showCreateAccount = false }) {
                        Image(systemName: "chevron.left")
                        Text("Back").fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .padding(.leading, 16)
                    Spacer()
                }
                .padding(.top, 16)

                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)

                UserInformationView(formState: $formState)

                PasswordField(
                    password: $formState.password,
                    isValid: $formState.isPasswordValid,
                    errorMessage: $formState.passwordErrorMessage,
                    bypassValidation: $bypassValidation,
                    validateField: { password in
                        if let validationMessage = ValidationUtility.validateField(password, type: .password) {
                            return (false, validationMessage.rawValue)
                        }
                        return (true, "")
                    }
                )

                ConfirmPasswordField(
                    confirmPassword: $formState.confirmPassword,
                    isValid: $formState.isConfirmPasswordValid,
                    password: $formState.password
                )

                BeltSection(belt: $belt, beltOptions: beltOptions, usePickerStyle: true)

/*
                // GYM INFORMATION SECTION
                Section(header: HStack {
                    Text("Gym Information").fontWeight(.bold)
                    Text("(Optional)").foregroundColor(.secondary).opacity(0.7)
                }.padding(.horizontal, 20)) {

                    IslandFormSections(
                        viewModel: islandViewModel,
                        profileViewModel: profileViewModel,
                        islandName: $islandDetails.islandName,
                        street: $islandDetails.street,
                        city: $islandDetails.city,
                        state: $islandDetails.state,
                        postalCode: $islandDetails.postalCode,
                        islandDetails: $islandDetails,
                        selectedCountry: $islandDetails.selectedCountry,
                        gymWebsite: $gymWebsite,
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
                        isSaveEnabled: $isSaveEnabled,
                        showValidationMessage: wantsToAddGym ? $showValidationMessage : .constant(false),
                        missingFields: $missingFields
                    )
                }
 
 
 */

                Button(action: handleCreateAccountButtonTapped) {
                    Text("Create Account")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .shadow(radius: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom)
                .disabled(isButtonDisabled)
                .onAppear {
                    Task { await countryService.fetchCountries() }
                }
            }
            .padding(.vertical)
            .background(Color(uiColor: .systemBackground))
        }
        .onChange(of: islandDetails.selectedCountry) {
            formState.selectedCountry = islandDetails.selectedCountry
        }

        // ✅ Unified Alert (handles success and validation/missing fields)
        .alert(
            currentAlertType?.title ?? alertTitle,
            isPresented: Binding<Bool>(
                get: { showAlert || currentAlertType != nil },
                set: { _ in
                    showAlert = false
                    currentAlertType = nil
                }
            )
        ) {
            Button("OK") {
                if let type = currentAlertType {
                    if type == .successAccount || type == .successAccountAndGym {
                        authenticationState.setIsAuthenticated(true)
                        authenticationState.navigateUnrestricted = true
                        authenticationState.accountCreatedSuccessfully = true
                        showCreateAccount = false
                    }
                }
            }
        } message: {
            Text(currentAlertType?.defaultMessage ?? alertMessage)
        }
    }

    // MARK: - Helpers
    private var wantsToAddGym: Bool {
        !islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty ||
        !gymWebsite.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Button Action
    private func handleCreateAccountButtonTapped() {
        Task {
            isButtonDisabled = true
            missingFields = getMissingFields()
            let (isValid, _) = isValidForm()

            if isValid {
                await createAccount(country: islandDetails.selectedCountry?.name.common ?? "United States")
            } else {
                // Dynamically build missing fields message
                let fieldList = missingFields.map { "- \($0)" }.joined(separator: "\n")
                alertTitle = "Fields Required"
                alertMessage = fieldList.isEmpty ? "Please complete all required fields." : "Please fill in the following fields:\n\(fieldList)"
                showAlert = true
                isButtonDisabled = false
            }
        }
    }
    
    private func getMissingFields() -> [String] {
        var fields: [String] = []

        if formState.userName.trimmingCharacters(in: .whitespaces).isEmpty { fields.append("Username") }
        if formState.name.trimmingCharacters(in: .whitespaces).isEmpty { fields.append("Full Name") }
        if formState.email.trimmingCharacters(in: .whitespaces).isEmpty { fields.append("Email") }
        if formState.password.trimmingCharacters(in: .whitespaces).isEmpty { fields.append("Password") }
        if formState.password != formState.confirmPassword { fields.append("Passwords do not match") }

        if wantsToAddGym {
            let gymFields: [(String, Bool)] = [
                ("Island Name", islandDetails.islandName.trimmingCharacters(in: .whitespaces).isEmpty),
                ("Street", islandDetails.street.trimmingCharacters(in: .whitespaces).isEmpty),
                ("City", islandDetails.city.trimmingCharacters(in: .whitespaces).isEmpty),
                ("State", islandDetails.state.trimmingCharacters(in: .whitespaces).isEmpty),
                ("Postal Code", islandDetails.postalCode.trimmingCharacters(in: .whitespaces).isEmpty)
            ]
            for (name, isEmpty) in gymFields where isEmpty { fields.append(name) }
        }

        return fields
    }

    
    // MARK: - Account Creation
    private func createAccount(country: String) async {
        isButtonDisabled = true  // Disable the button immediately

        do {
            // 1️⃣ Check if user already exists
            if await AuthViewModel.shared.userAlreadyExists(
                email: formState.email.lowercased(),
                userName: formState.userName
            ) {
                // Show alert for existing user
                await MainActor.run {
                    alertTitle = "Notice"
                    alertMessage = "An account with this email or username already exists."
                    showAlert = true
                    isButtonDisabled = false
                }
                return
            }

            // 2️⃣ Create the user
            let createdUser = try await AuthViewModel.shared.createUser(
                withEmail: formState.email,
                password: formState.password,
                userName: formState.userName,
                name: formState.name,
                belt: belt
            )

            // 3️⃣ Optionally create gym if island name exists
            if !islandDetails.islandName.isEmpty {
                _ = await createPirateIsland(for: createdUser)
            }

            // 4️⃣ Show success alert
            await MainActor.run {
                AuthViewModel.shared.currentUser = createdUser
                authenticationState.navigateUnrestricted = false  // block auto navigation

                currentAlertType = !islandDetails.islandName.isEmpty
                    ? .successAccountAndGym
                    : .successAccount

                alertTitle = currentAlertType?.title ?? "Notice"
                alertMessage = currentAlertType?.defaultMessage ?? ""
                showAlert = true
                isButtonDisabled = false
            }

        } catch {
            // 5️⃣ Handle errors gracefully
            await MainActor.run {
                handleCreateAccountError(error)
                isButtonDisabled = false
            }
        }
    }


    // MARK: - Island Creation
    private func createPirateIsland(for user: User) async -> String? {
        let (isValid, _) = ValidationUtility.validateIslandForm(
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
            selectedCountry: islandDetails.selectedCountry,
            gymWebsite: islandDetails.gymWebsite
        )
        guard isValid else { return nil }

        do {
            let newIsland = try await islandViewModel.createPirateIsland(
                islandDetails: islandDetails,
                createdByUserId: user.userID,
                gymWebsite: islandDetails.gymWebsite,
                country: islandDetails.selectedCountry?.cca2 ?? "US",
                selectedCountry: islandDetails.selectedCountry!,
                createdByUser: user
            )

            if !islandDetails.gymWebsite.isEmpty {
                let urlString = islandDetails.gymWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: urlString),
                      url.scheme == "http" || url.scheme == "https" else {
                    return nil
                }
            }

            return newIsland.islandName
        } catch {
            return nil
        }
    }

    // MARK: - Error Handling
    private func handleCreateAccountError(_ error: Error) {
        alertTitle = "Notice"
        alertMessage = getErrorMessage(error)
        showAlert = true
        resetAuthenticationState()
    }

    // MARK: - Form Validation
    func isValidForm() -> (isValid: Bool, message: String?) {
        if !formState.isUserNameValid { return (false, "Username is missing/invalid.") }
        if !formState.isNameValid { return (false, "Full name is missing/invalid.") }
        if !formState.isEmailValid { return (false, "Email address is missing/invalid.") }
        if !formState.isPasswordValid { return (false, "Password is missing/invalid.") }
        if formState.password != formState.confirmPassword { return (false, "Passwords do not match.") }

        if wantsToAddGym && !isAddressValid(for: islandDetails.selectedCountry?.cca2 ?? "") {
            return (false, "Please complete all required address fields for the gym.")
        }

        return (true, nil)
    }


    func isAddressValid(for countryCode: String) -> Bool {
        guard !countryCode.isEmpty else { return false }
        do {
            let requiredFields = try getAddressFields(for: countryCode)
            return !requiredFields.contains(where: { isIslandFieldEmpty($0) })
        } catch {
            return false
        }
    }

    private func isIslandFieldEmpty(_ field: AddressFieldType) -> Bool {
        switch field {
        case .street: return islandDetails.street.trimmingCharacters(in: .whitespaces).isEmpty
        case .city: return islandDetails.city.trimmingCharacters(in: .whitespaces).isEmpty
        case .state: return islandDetails.state.trimmingCharacters(in: .whitespaces).isEmpty
        case .postalCode: return islandDetails.postalCode.trimmingCharacters(in: .whitespaces).isEmpty
        case .province: return islandDetails.province.trimmingCharacters(in: .whitespaces).isEmpty
        case .neighborhood: return islandDetails.neighborhood.trimmingCharacters(in: .whitespaces).isEmpty
        case .complement: return islandDetails.complement.trimmingCharacters(in: .whitespaces).isEmpty
        case .region: return islandDetails.region.trimmingCharacters(in: .whitespaces).isEmpty
        case .county: return islandDetails.county.trimmingCharacters(in: .whitespaces).isEmpty
        case .governorate: return islandDetails.governorate.trimmingCharacters(in: .whitespaces).isEmpty
        case .additionalInfo: return islandDetails.additionalInfo.trimmingCharacters(in: .whitespaces).isEmpty
        case .department: return islandDetails.department.trimmingCharacters(in: .whitespaces).isEmpty
        case .parish: return islandDetails.parish.trimmingCharacters(in: .whitespaces).isEmpty
        case .district: return islandDetails.district.trimmingCharacters(in: .whitespaces).isEmpty
        case .entity: return islandDetails.entity.trimmingCharacters(in: .whitespaces).isEmpty
        case .municipality: return islandDetails.municipality.trimmingCharacters(in: .whitespaces).isEmpty
        case .division: return islandDetails.division.trimmingCharacters(in: .whitespaces).isEmpty
        case .emirate: return islandDetails.emirate.trimmingCharacters(in: .whitespaces).isEmpty
        case .zone: return islandDetails.zone.trimmingCharacters(in: .whitespaces).isEmpty
        case .block: return islandDetails.block.trimmingCharacters(in: .whitespaces).isEmpty
        case .apartment: return islandDetails.apartment.trimmingCharacters(in: .whitespaces).isEmpty
        case .multilineAddress: return islandDetails.multilineAddress.trimmingCharacters(in: .whitespaces).isEmpty
        case .island: return islandDetails.island.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func resetAuthenticationState() {
        authenticationState.reset()
        isUserProfileActive = false
    }

    func getErrorMessage(_ error: Error) -> String {
        if let pirateIslandError = error as? PirateIslandError {
            switch pirateIslandError {
            case .invalidInput: return "Invalid input"
            case .islandExists: return "Island already exists"
            case .geocodingError(let message): return "Geocoding error: \(message)"
            case .savingError: return "Saving error"
            case .islandNameMissing: return "Island name is missing"
            case .streetMissing: return "Street address is missing"
            case .cityMissing: return "City is missing"
            case .stateMissing: return "State is missing"
            case .postalCodeMissing: return "Postal code is missing"
            case .fieldMissing(let fieldName): return "\(fieldName) is missing."
            case .invalidGymWebsite: return "Gym Website appears to be invalid"
            }
        } else {
            let errorCode = (error as NSError).code
            switch CreateAccountError(rawValue: errorCode) {
            case .invalidEmailOrPassword: return "Invalid email or password."
            case .userNotFound: return "User not found."
            case .missingPermissions: return "Missing or insufficient permissions."
            case .emailAlreadyInUse: return AccountAuthViewError.userAlreadyExists.errorDescription ?? "Email already in use."
            default: return "Error creating account: \(error.localizedDescription)"
            }
        }
    }
}
