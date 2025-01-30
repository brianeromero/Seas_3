import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation
import os


// MARK: - Country Address Format
struct CountryAddressFormat {
    let requiredFields: [AddressFieldType] // Change this line
    let postalCodeValidationRegex: String?
}

let countryAddressFormats: [String: CountryAddressFormat] = addressFieldRequirements.reduce(into: [:]) { result, entry in
    result[entry.key] = CountryAddressFormat(
        requiredFields: entry.value,
        postalCodeValidationRegex: ValidationUtility.postalCodeRegexPatterns[entry.key]
    )
}

func getPostalCodeValidationRegex(for country: String) -> String? {
    return ValidationUtility.postalCodeRegexPatterns[country]
}

struct IslandFormSections: View {
    @ObservedObject var viewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var countryService = CountryService.shared


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


    @Binding var islandDetails: IslandDetails
    @Binding var selectedCountry: Country?
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    
    // Validation Bindings
    @Binding var isIslandNameValid: Bool
    @Binding var islandNameErrorMessage: String
    @Binding var isFormValid: Bool
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPickerPresented = false
    @State private var showValidationMessage = false
    
    // Binding the formState
    @Binding var formState: FormState

    var body: some View {
        VStack(spacing: 10) {
            // Country Picker Section
            countryPickerSection
            
            // Island Details Section
            islandDetailsSection
                .padding()
            
            // Website Section
            websiteSection
        }
        .padding()
        .onAppear {
            Task { await countryService.fetchCountries() }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Country Picker Section
    var countryPickerSection: some View {
        if countryService.isLoading {
            AnyView(ProgressView("Loading countries..."))
        } else if countryService.countries.isEmpty {
            AnyView(Text("No countries found."))
        } else {
            AnyView(UnifiedCountryPickerView(
                countryService: countryService,
                selectedCountry: $selectedCountry,
                isPickerPresented: $isPickerPresented
            )
            .onChange(of: selectedCountry) { newCountry in
                if let countryCode = newCountry?.cca2 {
                    // Normalize the country code
                    let normalizedCountryCode = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Normalized Country Code Set7896: \(normalizedCountryCode)") // Print the normalized code
                    do {
                        // Fetch address fields based on the normalized country code
                        let addressFields = try getAddressFields(for: normalizedCountryCode)
                        print("Address Fields Required789: \(addressFields)")
                    } catch {
                        print("Error fetching address fields789: \(error)")
                    }
                } else {
                    print("No country selected")
                }
                // Update address requirements for the new selected country
                updateAddressRequirements(for: newCountry)
            })
        }
    }



    
    // MARK: - Island Details Section
    var islandDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gym Name")
            TextField("Enter Gym Name", text: $islandDetails.islandName)
                .onChange(of: islandDetails.islandName) { newValue in
                    print("Gym Name Updated: \(newValue)")
                    validateFields(newValue) // Validation based on the updated value
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())


            // Address Fields View
            AddressFieldsView(
                requiredFields: requiredFields(for: selectedCountry),
                islandDetails: $islandDetails
            )


            if showValidationMessage {
                Text("Required fields are missing.")
                    .foregroundColor(.red)
            }
        }
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

    func processWebsiteURL(_ url: String) {
        guard !url.isEmpty else {
            islandDetails.gymWebsiteURL = nil
            return
        }
        let sanitizedURL = "https://" + stripProtocol(from: url)
        if ValidationUtility.validateURL(sanitizedURL) == nil {
            islandDetails.gymWebsiteURL = URL(string: sanitizedURL)
        } else {
            errorMessage = "Invalid URL format"
            showError = true
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

        // Ensure selectedCountry is non-nil and has a valid cca2 code
        guard let selectedCountry = selectedCountry, !selectedCountry.cca2.isEmpty else {
            setError("Please select a valid country.")
            return
        }

        // Proceed to validate the address based on cca2
        if validateAddress(for: selectedCountry.cca2) {
            await updateIslandLocation()
        } else {
            setError("Please fill in all required address fields.")
        }
    }

    func validateAddress(for country: String?) -> Bool {
        guard !islandDetails.islandName.isEmpty else { return true } // Skip validation if islandName is empty

        // Ensure the country is provided and not empty
        guard let countryName = country, !countryName.isEmpty else { return false }

        // Create the Country object using countryName
        let selectedCountry = Country(name: .init(common: countryName), cca2: "", flag: "")

        // Get the required fields for the selected country (using Country object)
        _ = requiredFields(for: selectedCountry)  // Now passing the Country object
        var isValid = true

        // Create a dictionary to map AddressField enum values to FormState properties
        let errorMessages: [AddressField: (String, String)] = [
            .state: ("State is required for \(countryName).", "stateErrorMessage"),
            .postalCode: ("Postal Code is required for \(countryName).", "postalCodeErrorMessage"),
            .street: ("Street is required for \(countryName).", "streetErrorMessage"),
            .city: ("City is required for \(countryName).", "cityErrorMessage"),
            .province: ("Province is required for \(countryName).", "provinceErrorMessage"),
            .region: ("Region is required for \(countryName).", "regionErrorMessage"),
            .district: ("District is required for \(countryName).", "districtErrorMessage"),
            .department: ("Department is required for \(countryName).", "departmentErrorMessage"),
            .governorate: ("Governorate is required for \(countryName).", "governorateErrorMessage"),
            .emirate: ("Emirate is required for \(countryName).", "emirateErrorMessage"),
            .county: ("County is required for \(countryName).", "countyErrorMessage"),
            .neighborhood: ("Neighborhood is required for \(countryName).", "neighborhoodErrorMessage"),
            .complement: ("Complement is required for \(countryName).", "complementErrorMessage"),
            .block: ("Block is required for \(countryName).", "blockErrorMessage"),
            .apartment: ("Apartment is required for \(countryName).", "apartmentErrorMessage"),
            .additionalInfo: ("Additional Info is required for \(countryName).", "additionalInfoErrorMessage"),
            .multilineAddress: ("Multiline Address is required for \(countryName).", "multilineAddressErrorMessage"),
            .parish: ("Parish is required for \(countryName).", "parishErrorMessage"),
            .entity: ("Entity is required for \(countryName).", "entityErrorMessage"),
            .municipality: ("Municipality is required for \(countryName).", "municipalityErrorMessage"),
            .division: ("Division is required for \(countryName).", "divisionErrorMessage"),
            .zone: ("Zone is required for \(countryName).", "zoneErrorMessage"),
            .island: ("Island is required for \(countryName).", "islandErrorMessage"),
            .country: ("Country is required for \(countryName).", "countryErrorMessage"),
        ]

        // Iterate over all fields in the AddressField enum
        for field in AddressField.allCases {
            switch field {
            case .state:
                if islandDetails.state.isEmptyOrWhitespace {
                    formState.stateErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.stateErrorMessage = ""
                }
            case .postalCode:
                if islandDetails.postalCode.isEmptyOrWhitespace {
                    formState.postalCodeErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.postalCodeErrorMessage = ""
                }
            case .street:
                if islandDetails.street.isEmptyOrWhitespace {
                    formState.streetErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.streetErrorMessage = ""
                }
            case .city:
                if islandDetails.city.isEmptyOrWhitespace {
                    formState.cityErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.cityErrorMessage = ""
                }
            case .province:
                if islandDetails.province.isEmptyOrWhitespace {
                    formState.provinceErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.provinceErrorMessage = ""
                }
            case .region:
                if islandDetails.region.isEmptyOrWhitespace {
                    formState.regionErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.regionErrorMessage = ""
                }
            case .district:
                if islandDetails.district.isEmptyOrWhitespace {
                    formState.districtErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.districtErrorMessage = ""
                }
            case .department:
                if islandDetails.department.isEmptyOrWhitespace {
                    formState.departmentErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.departmentErrorMessage = ""
                }
            case .governorate:
                if islandDetails.governorate.isEmptyOrWhitespace {
                    formState.governorateErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.governorateErrorMessage = ""
                }
            case .emirate:
                if islandDetails.emirate.isEmptyOrWhitespace {
                    formState.emirateErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.emirateErrorMessage = ""
                }
            case .county:
                if islandDetails.county.isEmptyOrWhitespace {
                    formState.countyErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.countyErrorMessage = ""
                }
            case .neighborhood:
                if islandDetails.neighborhood.isEmptyOrWhitespace {
                    formState.neighborhoodErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.neighborhoodErrorMessage = ""
                }
            case .complement:
                if islandDetails.complement.isEmptyOrWhitespace {
                    formState.complementErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.complementErrorMessage = ""
                }
            case .block:
                if islandDetails.block.isEmptyOrWhitespace {
                    formState.blockErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.blockErrorMessage = ""
                }
            case .apartment:
                if islandDetails.apartment.isEmptyOrWhitespace {
                    formState.apartmentErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.apartmentErrorMessage = ""
                }
            case .additionalInfo:
                if islandDetails.additionalInfo.isEmptyOrWhitespace {
                    formState.additionalInfoErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.additionalInfoErrorMessage = ""
                }
            case .multilineAddress:
                if islandDetails.multilineAddress.isEmptyOrWhitespace {
                    formState.multilineAddressErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.multilineAddressErrorMessage = ""
                }
            case .parish:
                if islandDetails.parish.isEmptyOrWhitespace {
                    formState.parishErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.parishErrorMessage = ""
                }
            case .entity:
                if islandDetails.entity.isEmptyOrWhitespace {
                    formState.entityErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.entityErrorMessage = ""
                }
            case .municipality:
                if islandDetails.municipality.isEmptyOrWhitespace {
                    formState.municipalityErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.municipalityErrorMessage = ""
                }
            case .division:
                if islandDetails.division.isEmptyOrWhitespace {
                    formState.divisionErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.divisionErrorMessage = ""
                }
            case .zone:
                if islandDetails.zone.isEmptyOrWhitespace {
                    formState.zoneErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.zoneErrorMessage = ""
                }
            case .island:
                if islandDetails.island.isEmptyOrWhitespace {
                    formState.islandErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.islandErrorMessage = ""
                }
            case .country:
                if islandDetails.country.isEmptyOrWhitespace {
                    formState.countryErrorMessage = errorMessages[field]?.0 ?? ""
                    isValid = false
                } else {
                    formState.countryErrorMessage = ""
                }
            }
        }

        return isValid
    }


    
    func getAddressFieldsSafely(for countryName: String) -> [AddressFieldType] {
        do {
            return try getAddressFields(for: countryName)
        } catch {
            os_log("Error getting address fields for country: %@", log: OSLog.default, type: .error, countryName)
            return defaultAddressFieldRequirements
        }
    }

    var requiredAddressFields: [AddressFieldType] {
        guard let countryName = selectedCountry?.name.common else {
            return defaultAddressFieldRequirements
        }
        
        return getAddressFieldsSafely(for: countryName)
    }

    private func validateForm() {
        print("validateForm()456 called: islandName = \(islandName)")

        // Validate island name
        let islandNameValid = !islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isIslandNameValid = islandNameValid
        islandNameErrorMessage = islandNameValid ? "" : "Gym name cannot be empty."

        // Validate address fields if islandName is provided
        let addressFieldsValid = requiredAddressFields.allSatisfy { field in
            let value = getValue(for: field)
            let errorMessage = "\(field.rawValue.capitalized) is required."
            switch field {
            case .street:
                formState.streetErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .city:
                formState.cityErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .state:
                formState.stateErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .province:
                formState.provinceErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .postalCode:
                formState.postalCodeErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .region:
                formState.regionErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .district:
                formState.districtErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .department:
                formState.departmentErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .governorate:
                formState.governorateErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .emirate:
                formState.emirateErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .county:
                formState.countyErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .neighborhood:
                formState.neighborhoodErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .complement:
                formState.complementErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .apartment:
                formState.apartmentErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .additionalInfo:
                formState.additionalInfoErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .multilineAddress:
                formState.multilineAddressErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .parish:
                formState.parishErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .entity:
                formState.entityErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .municipality:
                formState.municipalityErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .division:
                formState.divisionErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .zone:
                formState.zoneErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            case .island:
                formState.islandErrorMessage = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? errorMessage : ""
            default:
                break
            }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        // Validate overall form state
        isFormValid = islandNameValid && addressFieldsValid
    }



    private func getValue(for field: AddressFieldType) -> String {
        // Use a dictionary to map fields to values dynamically
        let fieldValues: [AddressFieldType: String] = [
            .state: islandDetails.state,
            .postalCode: islandDetails.postalCode,
            .street: islandDetails.street,
            .city: islandDetails.city,
            .province: islandDetails.province,
            .region: islandDetails.region,
            .district: islandDetails.district,
            .department: islandDetails.department,
            .governorate: islandDetails.governorate,
            .emirate: islandDetails.emirate,
            .block: islandDetails.block,
            .county: islandDetails.county,
            .neighborhood: islandDetails.neighborhood,
            .complement: islandDetails.complement,
            .apartment: islandDetails.apartment,
            .additionalInfo: islandDetails.additionalInfo,
            .multilineAddress: islandDetails.multilineAddress,
            .parish: islandDetails.parish,
            .entity: islandDetails.entity,
            .municipality: islandDetails.municipality,
            .division: islandDetails.division,
            .zone: islandDetails.zone,
            .island: islandDetails.island
        ]
        
        return fieldValues[field] ?? ""
    }

    
    private func getErrorMessage(for field: AddressFieldType, country: String) -> String {
        return "\(field.rawValue.capitalized) is required for \(country)."
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

    
    func validateGymNameAndAddress() -> Bool {
        // Validate the gym name
        guard !islandDetails.islandName.isEmpty else {
            setError("Gym name is required.")
            return false
        }

        // Validate that a country is selected
        guard let selectedCountry = selectedCountry, !selectedCountry.cca2.isEmpty else {
            setError("Select a country.")
            return false
        }

        // Pass the country's name (or cca2 if needed) to validateAddress
        guard validateAddress(for: selectedCountry.name.common) else {
            setError("Please fill in all required address fields.")
            return false
        }

        return true
    }

    
    // MARK: - Address Fields
    func requiredFields(for country: Country?) -> [AddressFieldType] {
        guard let countryCode = country?.cca2 else {
            // If there's no country code, return the default address fields, ensuring all fallbacks are handled correctly
            return defaultAddressFieldRequirements.map { field in
                AddressFieldType(rawValue: field.rawValue) ?? .street // Provide .street as the fallback case
            }
        }
        
        // If country code exists, use the country-specific address format
        return countryAddressFormats[countryCode]?.requiredFields.map { field in
            // Ensure AddressFieldType is converted from the raw value, fallback to .street if conversion fails
            AddressFieldType(rawValue: field.rawValue) ?? .street
        } ?? defaultAddressFieldRequirements.map { field in
            // Handle case where countryAddressFormats doesn't have a valid format
            AddressFieldType(rawValue: field.rawValue) ?? .street // Fallback to .street
        }
    }


    func updateAddressRequirements(for country: Country?) {
        islandDetails.requiredAddressFields = requiredFields(for: country)
    }

    // MARK: - Validation Logic
    func validateFields(_ fieldName: String? = nil) {
        let requiredFields = requiredFields(for: selectedCountry)
        
        // Directly reference your formState property here
        let formState = self.formState  // Assuming formState is a property in the current context
        
        let allValid = requiredFields.allSatisfy { field in
            // Access the corresponding FormState property
            let isValid: Bool
            
            switch field {
            case .street:
                isValid = formState.isStreetValid
            case .city:
                isValid = formState.isCityValid
            case .state:
                isValid = formState.isStateValid
            case .province:
                isValid = formState.isProvinceValid
            case .postalCode:
                isValid = formState.isPostalCodeValid
            case .region:
                isValid = formState.isRegionValid
            case .district:
                isValid = formState.isDistrictValid
            case .department:
                isValid = formState.isDepartmentValid
            case .governorate:
                isValid = formState.isGovernorateValid
            case .emirate:
                isValid = formState.isEmirateValid
            case .block:
                isValid = formState.isBlockValid
            case .county:
                isValid = formState.isCountyValid
            case .neighborhood:
                isValid = formState.isNeighborhoodValid
            case .complement:
                isValid = formState.isComplementValid
            case .apartment:
                isValid = formState.isApartmentValid
            case .additionalInfo:
                isValid = formState.isAdditionalInfoValid
            case .multilineAddress:
                isValid = formState.isMultilineAddressValid
            case .parish:
                isValid = formState.isParishValid
            case .entity:
                isValid = formState.isEntityValid
            case .municipality:
                isValid = formState.isMunicipalityValid
            case .division:
                isValid = formState.isDivisionValid
            case .zone:
                isValid = formState.isZoneValid
            case .island:
                isValid = formState.isIslandValid
            }
            
            return isValid
        }

        // Show or hide validation message based on whether the fields are valid
        showValidationMessage = !allValid
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
    
    // MARK: - Website Section
    var websiteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gym Website")
            TextField("Enter Gym Website", text: $islandDetails.gymWebsite)
                .onChange(of: islandDetails.gymWebsite) { processWebsiteURL($0) }
                .textFieldStyle(RoundedBorderTextFieldStyle())
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


extension String {
    var isEmptyOrWhitespace: Bool {
        self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}


// Preview
struct IslandFormSections_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
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
                selectedCountry: .constant(Country(name: .init(common: "United States"), cca2: "US", flag: "")),
                islandDetails: .constant(IslandDetails(selectedCountry: Country(name: .init(common: "United States"), cca2: "US", flag: ""))),
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
                province: .constant("California"), // Update placeholder
                neighborhood: .constant("Neighborhood A"),
                complement: .constant(""),
                apartment: .constant("Apt 101"),
                additionalInfo: .constant("Open 24/7"),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: .init(common: "United States"), cca2: "US", flag: "")),
                islandDetails: .constant(IslandDetails(
                    islandName: "My Gym",
                    street: "123 Main St",
                    city: "Anytown",
                    state: "CA",
                    postalCode: "12345",
                    selectedCountry: Country(name: .init(common: "United States"), cca2: "US", flag: "")
                )),
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
                province: .constant("Ontario"), // Update placeholder
                neighborhood: .constant("Neighborhood B"),
                complement: .constant(""),
                apartment: .constant("Apt 202"),
                additionalInfo: .constant("Open 9am to 5pm"),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: .constant(Country(name: .init(common: "Canada"), cca2: "CA", flag: "")),
                islandDetails: .constant(IslandDetails(
                    islandName: "My Gym",
                    street: "123 Main St",
                    city: "Anytown",
                    state: "ON",
                    postalCode: "M5V",
                    selectedCountry: Country(name: .init(common: "Canada"), cca2: "CA", flag: "")
                )),
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
                selectedCountry: .constant(Country(name: .init(common: "United States"), cca2: "US", flag: "")),
                islandDetails: .constant(IslandDetails(
                    islandName: "My Gym",
                    selectedCountry: Country(name: .init(common: "United States"), cca2: "US", flag: "")
                )),
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
            profileViewModel: profileViewModel,
            countryService: CountryService(), // Provide the correct service
            islandName: islandName,
            street: street,
            city: city,
            state: state,
            postalCode: postalCode,
            province: province,
            neighborhood: neighborhood,
            complement: complement,
            apartment: apartment,
            region: .constant(""), // Provide default values if needed
            county: .constant(""),
            governorate: .constant(""),
            additionalInfo: additionalInfo,
            islandDetails: islandDetails,
            selectedCountry: selectedCountry,
            showAlert: showAlert,
            alertMessage: alertMessage,
            gymWebsite: gymWebsite,
            gymWebsiteURL: gymWebsiteURL,
            isIslandNameValid: .constant(true), // Add default values
            islandNameErrorMessage: .constant(""), // Add default values
            isFormValid: .constant(true), // Add default values
            formState: .constant(FormState()) // Add default values
        )
    }
}
