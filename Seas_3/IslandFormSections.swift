import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation
import os


struct CountryAddressFormat {
    let requiredFields: [AddressField]
    let postalCodeValidationRegex: String?
}

let countryAddressFormats: [String: CountryAddressFormat] = {
    var formats = [String: CountryAddressFormat]()
    for (country, fields) in addressFieldRequirements {
        formats[country] = CountryAddressFormat(
            requiredFields: fields.map { AddressField(rawValue: $0.rawValue) ?? .street },
            postalCodeValidationRegex: getPostalCodeValidationRegex(for: country)
        )
    }
    return formats
}()

func getPostalCodeValidationRegex(for country: String) -> String? {
    return ValidationUtility.postalCodeRegexPatterns[country]
}

struct IslandFormSections: View {
    @ObservedObject var viewModel: PirateIslandViewModel
    @Binding var islandName: String
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var postalCode: String
    @Binding var province: String
    @Binding var neighborhood: String
    @Binding var complement: String
    @Binding var apartment: String
    @Binding var region: String
    @Binding var county: String
    @Binding var governorate: String
    @Binding var additionalInfo: String
    @State private var showError = false
    @State private var errorMessage = ""
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var selectedCountry: Country?
    @Binding var islandDetails: IslandDetails
    @ObservedObject var profileViewModel: ProfileViewModel
    @State private var showValidationMessage = false

    var body: some View {
        VStack(spacing: 10) {
            UnifiedCountryPickerView(
                countryService: CountryService(),
                selectedCountry: $selectedCountry,
                isPickerPresented: .constant(false)
            )
            islandDetailsSection
            websiteSection
        }
        .padding()
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    var islandDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gym Name")
            TextField("Enter Gym Name", text: $islandDetails.islandName)
                .onChange(of: islandDetails.islandName) { newValue in validateFields() }
                .textFieldStyle(RoundedBorderTextFieldStyle())

            let requiredFields = requiredFields(for: selectedCountry)
            AddressFieldsView(requiredFields: requiredFields, islandDetails: $islandDetails)

            if showValidationMessage {
                Text("Required fields are missing.")
                    .foregroundColor(.red)
            }
        }
    }
    
    func requiredFields(for country: Country?) -> [AddressFieldType] {
        guard let countryCode = country?.cca2 else { return defaultAddressFieldRequirements }
        return getAddressFields(for: countryCode)
    }


    func addressField(for field: AddressField) -> some View {
        switch field {
        case .street: return AnyView(TextField("Street", text: $islandDetails.street))
        case .city: return AnyView(TextField("City", text: $islandDetails.city))
        case .state: return AnyView(TextField("State", text: $islandDetails.state))
        case .postalCode: return AnyView(TextField("Postal Code", text: $islandDetails.postalCode))
        case .province: return AnyView(TextField("Province", text: $islandDetails.province))
        case .neighborhood: return AnyView(TextField("Neighborhood", text: $islandDetails.neighborhood))
        case .complement: return AnyView(TextField("Complement", text: $islandDetails.complement))
        case .apartment: return AnyView(TextField("Apartment", text: $islandDetails.apartment))
        case .region: return AnyView(TextField("Region", text: $islandDetails.region))
        case .county: return AnyView(TextField("County", text: $islandDetails.county))
        case .governorate: return AnyView(TextField("Governorate", text: $islandDetails.governorate))
        case .additionalInfo: return AnyView(TextField("Additional Info", text: $islandDetails.additionalInfo))
        default: return AnyView(EmptyView())
        }
    }

    func processWebsiteURL() {
        guard !islandDetails.gymWebsite.isEmpty else { islandDetails.gymWebsiteURL = nil; return }
        let fullURLString = "https://" + stripProtocol(from: islandDetails.gymWebsite)
        if validateURL(fullURLString) {
            islandDetails.gymWebsiteURL = URL(string: fullURLString)
        } else {
            self.showError = true
            self.errorMessage = "Invalid URL format"
            islandDetails.gymWebsite = ""
        }
    }

    func stripProtocol(from urlString: String) -> String {
        if urlString.lowercased().starts(with: "http://") {
            return String(urlString.dropFirst(7))
        } else if urlString.lowercased().starts(with: "https://") {
            return String(urlString.dropFirst(8))
        }
        return urlString
    }
    
    func validateGymDetails() async {
        guard !islandDetails.islandName.isEmpty else {
            setError("Gym name is required.")
            return
        }

        guard let selectedCountry = selectedCountry else {
            setError("Select a country.")
            return
        }

        if validateAddress(for: selectedCountry.name.common) {
            await updateIslandLocation()
        } else {
            setError("Please fill in all required fields.")
        }
    }
    
    func validateAddress(for country: String?) -> Bool {
        // Ensure the country is provided
        guard let countryName = country else { return false }
        
        // Create a selectedCountry object
        let selectedCountry = Country(name: .init(common: countryName), cca2: "", flag: "")
        
        // Get the required fields for the selected country
        let requiredFields = requiredFields(for: selectedCountry)
        
        // Validate all required fields
        let areFieldsValid = requiredFields.allSatisfy { field in
            switch field {
            case .street: return !islandDetails.street.isEmpty
            case .city: return !islandDetails.city.isEmpty
            case .state: return !islandDetails.state.isEmpty
            case .postalCode: return !islandDetails.postalCode.isEmpty
            case .province: return !islandDetails.province.isEmpty
            case .neighborhood: return !islandDetails.neighborhood.isEmpty
            case .complement: return !islandDetails.complement.isEmpty
            case .apartment: return !islandDetails.apartment.isEmpty
            case .region: return !islandDetails.region.isEmpty
            case .county: return !islandDetails.county.isEmpty
            case .governorate: return !islandDetails.governorate.isEmpty
            case .additionalInfo: return !islandDetails.additionalInfo.isEmpty
            case .district: return !islandDetails.district.isEmpty
            case .department: return !islandDetails.department.isEmpty
            case .emirate: return !islandDetails.emirate.isEmpty
            case .block: return !islandDetails.block.isEmpty
            case .multilineAddress: return !islandDetails.multilineAddress.isEmpty
            case .parish: return !islandDetails.parish.isEmpty  // Validate 'parish' field
            case .entity: return !islandDetails.entity.isEmpty  // Validate 'entity' field
            case .municipality: return !islandDetails.municipality.isEmpty  // Validate 'municipality' field
            case .division: return !islandDetails.division.isEmpty  // Validate 'division' field
            case .zone: return !islandDetails.zone.isEmpty  // Validate 'zone' field
            }
        }

        
        // Get the postal code validation regex for the country
        guard let postalCodeValidationRegex = countryAddressFormats[selectedCountry.cca2]?.postalCodeValidationRegex else {
            return false
        }
        
        // Validate the postal code if it's non-empty
        let isPostalCodeValid = !islandDetails.postalCode.isEmpty &&
            ValidationUtility.validatePostalCode(
                islandDetails.postalCode,
                for: postalCodeValidationRegex
            ) != nil
        
        // Return the final validation result
        return areFieldsValid && isPostalCodeValid
    }
    
    func updateIslandLocation() async {
        Logger.logCreatedByIdEvent(createdByUserId: profileViewModel.name, fileName: "IslandFormSections", functionName: "updateIslandLocation")

        do {
            // Ensure that all required fields are populated before making the update
            let islandDetails = IslandDetails(
                islandName: islandDetails.islandName,
                street: islandDetails.street,
                city: islandDetails.city,
                state: islandDetails.state,
                postalCode: islandDetails.postalCode,
                gymWebsite: islandDetails.gymWebsite,
                gymWebsiteURL: islandDetails.gymWebsiteURL
            )
            
            // Update the PirateIsland with the new IslandDetails
            try await viewModel.updatePirateIsland(
                island: PirateIsland(),
                islandDetails: islandDetails,
                lastModifiedByUserId: profileViewModel.name
            )
        } catch {
            self.errorMessage = "Error updating island location: \(error.localizedDescription)"
            self.showError = true
        }
    }

    
    func setError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func isValidPostalCode(_ postalcode: String, regex: String?) -> Bool {
        guard let regex = regex else { return true }
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: islandDetails.postalCode)
    }

    
    func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
            return false
        }
        return true
    }
    
    func validateGymNameAndAddress() -> Bool {
        // Validate the gym name
        guard !islandDetails.islandName.isEmpty else {
            setError("Gym name is required.")
            return false
        }

        // Validate that a country is selected
        guard let selectedCountry = selectedCountry else {
            setError("Select a country.")
            return false
        }

        // Pass the country's name to validateAddress
        guard validateAddress(for: selectedCountry.name.common) else {
            setError("Please fill in all required address fields.")
            return false
        }

        return true
    }

    func validateFields() {
        let invalidFields = requiredFields(for: selectedCountry).compactMap { fieldType -> AddressField? in
            AddressField(rawValue: fieldType.rawValue)
        }.filter { field in
            let value = binding(for: field).wrappedValue
            return value.isEmpty
        }
        showValidationMessage = !invalidFields.isEmpty
    }


    func saveButtonAction() async {
        if !validateGymNameAndAddress() {
            self.showError = true
            return
        }

        do {
            try await viewModel.updatePirateIsland(
                island: PirateIsland(),
                islandDetails: islandDetails,
                lastModifiedByUserId: profileViewModel.name
            )
            print("Island data saved successfully")
        } catch {
            print("Error saving island data: \(error.localizedDescription)")
            self.errorMessage = "Error saving island data: \(error.localizedDescription)"
            self.showError = true
        }
    }
    
    func binding(for field: AddressField) -> Binding<String> {
         switch field {
         case .street:
             return $islandDetails.street
         case .city:
             return $islandDetails.city
         case .postalCode:
             return $islandDetails.postalCode
         case .state:
             return $islandDetails.state
         case .province:
             return $islandDetails.province
         case .region, .county, .governorate:
             return $islandDetails.region
         case .neighborhood:
             return $islandDetails.neighborhood
         case .complement:
             return $islandDetails.complement
         case .apartment:
             return $islandDetails.apartment
         case .additionalInfo:
             return $islandDetails.additionalInfo
         default:
             fatalError("Unhandled AddressField: \(field.rawValue)")
         }
     }
    
    var websiteSection: some View {
        Section(header: Text("Gym Website").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Website/Facebook/Instagram")
                TextField("Enter Website or Facebook or Instagram URL", text: $islandDetails.gymWebsite)
                    .onChange(of: islandDetails.gymWebsite) { newValue in processWebsiteURL() }
                    .keyboardType(.URL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
        }
    }
}

extension Binding where Value == String? {
    func defaultValue(_ defaultValue: String) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

extension View {
    func modifierForField(_ field: AddressField) -> some View {
        switch field {
        case .postalCode:
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


//Preview
struct IslandFormSections_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty form
            IslandFormSectionPreview(
                islandName: .constant(""),
                street: .constant(""),
                city: .constant(""),
                state: .constant(""),
                postalCode: .constant(""),
                province: .constant(""),
                neighborhood: .constant(""),
                complement: .constant(""),
                apartment: .constant(""),
                additionalInfo: .constant(""),
                gymWebsite: .constant(""),
                gymWebsiteURL: .constant(nil),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US", flag: "")),
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
                postalCode: .constant("12345"),
                province: .constant(""),
                neighborhood: .constant("Neighborhood A"),
                complement: .constant(""),
                apartment: .constant("Apt 101"),
                additionalInfo: .constant("Open 24/7"),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US", flag: "")),
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
                postalCode: .constant("M5V"),
                province: .constant("Ontario"),
                neighborhood: .constant("Neighborhood B"),
                complement: .constant(""),
                apartment: .constant("Apt 202"),
                additionalInfo: .constant("Open 9am to 5pm"),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "Canada"), cca2: "CA", flag: "")),
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
                postalCode: .constant(""),
                province: .constant(""),
                neighborhood: .constant(""),
                complement: .constant(""),
                apartment: .constant(""),
                additionalInfo: .constant(""),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US", flag: "")),
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
    var postalCode: Binding<String>
    var province: Binding<String>
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
    var profileViewModel: ProfileViewModel

    var body: some View {
        IslandFormSections(
            viewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
            islandName: islandName,
            street: street,
            city: city,
            state: state,
            postalCode: postalCode,
            province: province,
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
