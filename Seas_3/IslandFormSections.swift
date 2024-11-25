import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation
import os


struct CountryAddressFormat {
    let requiredFields: [AddressField]
    let zipValidationRegex: String?
}

let countryAddressFormats: [String: CountryAddressFormat] = {
    var formats = [String: CountryAddressFormat]()
    for (country, fields) in addressFieldRequirements {
        formats[country] = CountryAddressFormat(
            requiredFields: fields.map { AddressField(rawValue: $0.rawValue) ?? .street },
            zipValidationRegex: getZipValidationRegex(for: country)
        )
    }
    return formats
}()

func getZipValidationRegex(for country: String) -> String? {
    return ValidationUtility.zipRegexPatterns[country]
}

struct IslandFormSections: View {
    @ObservedObject var viewModel: PirateIslandViewModel
    @Binding var islandName: String
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    @Binding var province: String
    @Binding var postalCode: String
    @Binding var neighborhood: String
    @Binding var complement: String
    @Binding var apartment: String
    @Binding var region: String
    @Binding var county: String
    @Binding var governorate: String
    @Binding var additionalInfo: String
    @State private var countries: [Country] = []
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var selectedCountry: Country?
    @Binding var islandDetails: IslandDetails
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showValidationMessage = false
    @ObservedObject var profileViewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: 10) {
            UnifiedCountryPickerView(selectedCountry: $selectedCountry)
            islandDetailsSection
            websiteSection
        }
        .padding()
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear(perform: fetchCountries)
    }

    var islandDetailsSection: some View {
        Section(header: Text("Gym Details").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Name")
                TextField("Enter Gym Name", text: $islandName)
                    .onChange(of: islandName) { newValue in
                        os_log("Island name changed to '%@'", log: .default, type: .info, islandName)
                        Task { await validateGymDetails() }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: islandDetails.islandName) { newValue in
                        print("Updated island details: \(islandDetails)")
                    }

                AddressFieldsView(
                    selectedCountry: $selectedCountry,
                    street: $street,
                    city: $city,
                    state: $state,
                    zip: $zip,
                    neighborhood: $neighborhood,
                    complement: $complement,
                    apartment: $apartment,
                    additionalInfo: $additionalInfo
                )
                .onChange(of: islandDetails.street) { newValue in
                    print("Updated street: \(newValue)")
                }

                if showValidationMessage {
                    Text("Required fields are missing.")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
    }

    
    // MARK: - Helper Functions
    func requiredFields(for country: Country?) -> [AddressField] {
        guard let country = country else { return [] }
        return countryAddressFormats[country.cca2]?.requiredFields ?? [.street, .city, .state, .postalCode]
    }

    // Inside IslandFormSections
    func addressField(for field: AddressField) -> some View {
        AddressFieldView(field: field, islandDetails: $islandDetails)
            .onChange(of: AddressBindingHelper.binding(for: field, islandDetails: $islandDetails).wrappedValue) { _ in
                Task {
                    await validateGymDetails()
                }
            }
    }


    func binding(for field: AddressField) -> Binding<String> {
        switch field {
        case .street:
            return $street
        case .city:
            return $city
        case .postalCode, .postcode:
            return $postalCode
        case .pincode:
            return $postalCode
        case .zip:
            return $zip
        case .state:
            return $state
        case .province:
            return $province
        case .region, .district, .department, .emirate:
            return $region
        case .county:
            return $county
        case .governorate:
            return $governorate
        case .neighborhood:
            return .constant("")
        case .complement:
            return .constant("")
        case .block:
            return .constant("")
        case .apartment:
            return .constant("")
        case .country:
            return .constant("")
        case .additionalInfo:
            return .constant("")
        case .multilineAddress:
            return .constant("")
        @unknown default:
            fatalError("Unhandled AddressField: \(field.rawValue)")
        }
    }

    var websiteSection: some View {
        Section(header: Text("Gym Website").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Website/Facebook/Instagram")
                TextField("Enter Website or Facebook or Instagram URL", text: $gymWebsite, onEditingChanged: { _ in
                    processWebsiteURL()
                })
                .keyboardType(.URL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
        }
    }

    func fetchCountries() {
        print("Fetching countries...") // Log when fetching starts
        CountryService.shared.fetchCountries { fetchedCountries in
            if let fetchedCountries = fetchedCountries {
                // Sort the countries alphabetically by their common name
                DispatchQueue.main.async {
                    self.countries = fetchedCountries.sorted { $0.name.common < $1.name.common }
                    
                    // Set the selected country to "US" if available, or fall back to the first country in the list
                    if let firstCountry = self.countries.first {
                        self.selectedCountry = self.countries.first { $0.cca2 == "US" } ?? firstCountry
                        print("Selected country: \(self.selectedCountry?.name.common ?? "None")")
                    }
                }
            } else {
                print("Failed to fetch countries")
                // Handle the case where countries couldn't be fetched (e.g., show an alert to the user)
            }
        }
    }

    func validateGymDetails() async {
        guard !islandName.isEmpty else {
            setError("Gym name is required.")
            return
        }

        guard let selectedCountry = selectedCountry else {
            setError("Select a country.")
            return
        }

        if validateAddress(for: selectedCountry) {
            await updateIslandLocation()
        } else {
            setError("Please fill in all required fields.")
        }
    }
    
    func validateAddress(for country: Country) -> Bool {
        let requiredFields = requiredFields(for: country)
        let allFieldsValid = requiredFields.allSatisfy { !binding(for: $0).wrappedValue.isEmpty }
        let zipValid = isValidZip(zip, regex: countryAddressFormats[country.cca2]?.zipValidationRegex)
        return allFieldsValid && zipValid
    }


    func setError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func updateIslandLocation() async {
        Logger.logCreatedByIdEvent(createdByUserId: profileViewModel.name, fileName: "IslandFormSections", functionName: "updateIslandLocation")

        // Update island location data in view model
        do {
            try await viewModel.updatePirateIsland(
                island: PirateIsland(), // Replace with the actual island object
                islandDetails: IslandDetails(
                    islandName: islandName,
                    street: street,
                    city: city,
                    state: state,
                    zip: zip,
                    gymWebsite: gymWebsite,
                    gymWebsiteURL: gymWebsiteURL,
                    country: selectedCountry?.name.common ?? ""
                ),
                lastModifiedByUserId: profileViewModel.name // Replace with actual user ID
            )
        } catch {
            self.errorMessage = "Error updating island location: \(error.localizedDescription)"
            self.showError = true
        }
    }
    
    func isValidZip(_ zip: String, regex: String?) -> Bool {
        guard let regex = regex else { return true }
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: zip)
    }
    
    func validateGymNameAndAddress() -> Bool {
        // Validation logic to ensure fields are not empty
        return !islandName.isEmpty && !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty
    }

    private func validateAddress() -> Bool {
        !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty && isValidZip(zip, regex: countryAddressFormats[selectedCountry?.cca2 ?? "US"]?.zipValidationRegex)
    }


    func processWebsiteURL() {
        guard !gymWebsite.isEmpty else { gymWebsiteURL = nil; return }
        let fullURLString = "https://" + stripProtocol(from: gymWebsite)
        if validateURL(fullURLString) {
            gymWebsiteURL = URL(string: fullURLString)
        } else {
            showAlert = true
            alertMessage = "Invalid URL format"
            gymWebsite = ""
        }
    }

    private func stripProtocol(from urlString: String) -> String {
        if urlString.lowercased().starts(with: "http://") {
            return String(urlString.dropFirst(7))
        } else if urlString.lowercased().starts(with: "https://") {
            return String(urlString.dropFirst(8))
        }
        return urlString
    }

    func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    private func validateFields() -> Bool {
        let createdByUserId = profileViewModel.name // Assuming profileViewModel is accessible
        let (isValid, errorMessage) = ValidationUtility.validateIslandForm(
            islandName: islandName,
            street: street,
            city: city,
            state: state,
            zip: zip,
            selectedCountry: selectedCountry,
            createdByUserId: createdByUserId,
            gymWebsite: gymWebsite
        )
        self.errorMessage = errorMessage
        return isValid
    }
    
    func saveButtonAction() async {
        Logger.logCreatedByIdEvent(createdByUserId: "userId", fileName: "IslandFormSections", functionName: "saveButtonAction")
        if !validateGymNameAndAddress() {
            showError = true
            return
        }

        do {
            try await viewModel.updatePirateIsland(
                island: PirateIsland(), // Replace with the actual island object
                islandDetails: IslandDetails(
                    islandName: islandName,
                    street: street,
                    city: city,
                    state: state,
                    zip: zip,
                    gymWebsite: gymWebsite,
                    gymWebsiteURL: gymWebsiteURL,
                    country: selectedCountry?.name.common ?? ""
                ),
                lastModifiedByUserId: "userId" // Replace with actual user ID
            )
            print("Island data saved successfully")
        } catch {
            print("Error saving island data: \(error.localizedDescription)")
            self.errorMessage = "Error saving island data: \(error.localizedDescription)"
            self.showError = true
        }
    }
}

extension View {
    func modifierForField(_ field: AddressField) -> some View {
        switch field {
        case .zip, .postalCode, .postcode, .pincode:
            return self.keyboardType(.numberPad)
        case .city, .state, .street:
            return self.keyboardType(.default)
        default:
            return self.keyboardType(.default) // Default for non-specific fields
        }
    }
}


extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

struct IslandFormSections_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty form
            IslandFormSectionPreview(
                islandName: .constant(""),
                street: .constant(""),
                city: .constant(""),
                state: .constant(""),
                zip: .constant(""),
                province: .constant(""),
                postalCode: .constant(""),
                neighborhood: .constant(""),
                complement: .constant(""),
                apartment: .constant(""),
                additionalInfo: .constant(""),
                gymWebsite: .constant(""),
                gymWebsiteURL: .constant(nil),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US")),
                islandDetails: .constant(IslandDetails()),
                profileViewModel: ProfileViewModel(viewContext: PersistenceController.shared.container.viewContext)
            )
            .previewDisplayName("Empty Form")
            
            // Filled form (US)
            IslandFormSectionPreview(
                islandName: .constant("My Gym"),
                street: .constant("123 Main St"),
                city: .constant("Anytown"),
                state: .constant("CA"),
                zip: .constant("12345"),
                province: .constant(""),
                postalCode: .constant(""),
                neighborhood: .constant("Neighborhood A"),
                complement: .constant(""),
                apartment: .constant("Apt 101"),
                additionalInfo: .constant("Open 24/7"),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US")),
                islandDetails: .constant(IslandDetails()),
                profileViewModel: ProfileViewModel(viewContext: PersistenceController.shared.container.viewContext)
            )
            .previewDisplayName("Filled Form (US)")

            // Filled form (Canada)
            IslandFormSectionPreview(
                islandName: .constant("My Gym"),
                street: .constant("123 Main St"),
                city: .constant("Anytown"),
                state: .constant("ON"),
                zip: .constant(""),
                province: .constant("Ontario"),
                postalCode: .constant("M5V"),
                neighborhood: .constant("Neighborhood B"),
                complement: .constant(""),
                apartment: .constant("Apt 202"),
                additionalInfo: .constant("Open 9am to 5pm"),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "Canada"), cca2: "CA")),
                islandDetails: .constant(IslandDetails()),
                profileViewModel: ProfileViewModel(viewContext: PersistenceController.shared.container.viewContext)
            )
            .previewDisplayName("Filled Form (Canada)")

            // Invalid form
            IslandFormSectionPreview(
                islandName: .constant("My Gym"),
                street: .constant(""),
                city: .constant(""),
                state: .constant(""),
                zip: .constant(""),
                province: .constant(""),
                postalCode: .constant(""),
                neighborhood: .constant(""),
                complement: .constant(""),
                apartment: .constant(""),
                additionalInfo: .constant(""),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US")),
                islandDetails: .constant(IslandDetails()),
                profileViewModel: ProfileViewModel(viewContext: PersistenceController.shared.container.viewContext)
            )
            .previewDisplayName("Invalid Form")
        }
    }
}

struct IslandFormSectionPreview: View {
    var islandName: Binding<String>
    var street: Binding<String>
    var city: Binding<String>
    var state: Binding<String>
    var zip: Binding<String>
    var province: Binding<String>
    var postalCode: Binding<String>
    var neighborhood: Binding<String>
    var complement: Binding<String>
    var apartment: Binding<String>
    var additionalInfo: Binding<String>
    var gymWebsite: Binding<String>
    var gymWebsiteURL: Binding<URL?>
    var showAlert: Binding<Bool>
    var alertMessage: Binding<String>
    var selectedCountry: Binding<Country?>
    var islandDetails: Binding<IslandDetails>
    var profileViewModel: ProfileViewModel // Define the type of profileViewModel

    var body: some View {
        IslandFormSections(
            viewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
            islandName: islandName,
            street: street,
            city: city,
            state: state,
            zip: zip,
            province: province,
            postalCode: postalCode,
            neighborhood: neighborhood,
            complement: complement,
            apartment: apartment,
            region: .constant(""),
            county: .constant(""),
            governorate: .constant(""),
            additionalInfo: additionalInfo,
            gymWebsite: gymWebsite,
            gymWebsiteURL: gymWebsiteURL,
            showAlert: showAlert,
            alertMessage: alertMessage,
            selectedCountry: selectedCountry,
            islandDetails: islandDetails,
            profileViewModel: profileViewModel
        )
    }
}

