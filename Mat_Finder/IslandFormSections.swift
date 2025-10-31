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
    let countryCode = entry.key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    result[countryCode] = CountryAddressFormat(
        requiredFields: entry.value,
        postalCodeValidationRegex: ValidationUtility.postalCodeRegexPatterns[countryCode]
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

    @Binding var islandDetails: IslandDetails
    @Binding var selectedCountry: Country?
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    
    // Additional Bindings
    @Binding var province: String
    @Binding var neighborhood: String
    @Binding var complement: String
    @Binding var apartment: String
    @Binding var region: String
    @Binding var county: String
    @Binding var governorate: String
    @Binding var additionalInfo: String
    @Binding var department: String
    @Binding var parish: String
    @Binding var district: String
    @Binding var entity: String
    @Binding var municipality: String
    @Binding var division: String
    @Binding var emirate: String
    @Binding var zone: String
    @Binding var block: String
    @Binding var island: String

    
    // Validation Bindings
    @Binding var isIslandNameValid: Bool
    @Binding var islandNameErrorMessage: String
    @Binding var isFormValid: Bool
    
    // Alerts and Toasts
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPickerPresented = false
    @State private var showValidationMessage = false
    @State private var successMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    
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
                .onChange(of: selectedCountry) { oldCountry, newCountry in // Use the new signature
                if let countryCode = newCountry?.cca2 {
                    // Normalize the country code
                    let normalizedCountryCode = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Normalized Country Code Set7896: \(normalizedCountryCode)") // Print the normalized code
                    
                    // Fetch address fields using the safe method
                    let addressFields = getAddressFieldsSafely(for: normalizedCountryCode)
                    print("Address Fields Required789: \(addressFields)")
                } else {
                    print("No country selected789")
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
                .onChange(of: islandDetails.islandName) { oldName, newValue in // Use the new signature
                    print("Gym Name Updated: \(newValue)")
                    validateFields() // Validation based on the updated value
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Address Fields View
            VStack {
                // Fetch the required fields using the safer method
                let requiredFields = getAddressFieldsSafely(for: selectedCountry?.cca2)

                // Dynamically generate address fields
                ForEach(requiredFields, id: \.self) { field in
                    addressField(for: field)
                        .textFieldStyle(RoundedBorderTextFieldStyle()) // Apply the textFieldStyle here
                }
            }
            .padding(.top)

            // Only show the validation message if Gym Name is not empty
            if !islandDetails.islandName.isEmpty && showValidationMessage {
                Text("Required fields are missing.")
                    .foregroundColor(.red)
            }
        }
    }


    // MARK: - Address Field Dynamic Generation
    @ViewBuilder
    func addressField(for field: AddressFieldType) -> some View {
        switch field {
        case .street:
            TextField("Street", text: $islandDetails.street)
        case .city:
            TextField("City", text: $islandDetails.city)
        case .state:
            TextField("State", text: $islandDetails.state)
        case .postalCode:
            TextField("Postal Code", text: $islandDetails.postalCode)
        case .province:
            TextField("Province", text: $islandDetails.province)
        case .neighborhood:
            TextField("Neighborhood", text: $islandDetails.neighborhood)
        case .complement:
            TextField("Complement", text: $islandDetails.complement)
        case .apartment:
            TextField("Apartment", text: $islandDetails.apartment)
        case .region:
            TextField("Region", text: $islandDetails.region)
        case .county:
            TextField("County", text: $islandDetails.county)
        case .governorate:
            TextField("Governorate", text: $islandDetails.governorate)
        case .additionalInfo:
            TextField("Additional Info", text: $islandDetails.additionalInfo)
        case .island:
            TextField("Island", text: $islandDetails.island)
        case .department:
            TextField("Department", text: $islandDetails.department)  // Added
        case .parish:
            TextField("Parish", text: $islandDetails.parish)  // Added
        case .district:
            TextField("District", text: $islandDetails.district)  // Added
        case .entity:
            TextField("Entity", text: $islandDetails.entity)  // Added
        case .municipality:
            TextField("Municipality", text: $islandDetails.municipality)  // Added
        case .division:
            TextField("Division", text: $islandDetails.division)  // Added
        case .emirate:
            TextField("Emirate", text: $islandDetails.emirate)  // Added
        case .zone:
            TextField("Zone", text: $islandDetails.zone)  // Added
        case .block:
            TextField("Block", text: $islandDetails.block)  // Added
        default:
            EmptyView()
        }
    }

    
    // MARK: - Website Section
    var websiteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instagram/Facebook/Website")
                .font(.headline)
            TextField("Enter Instagram/Facebook/Website", text: $islandDetails.gymWebsite)
                // Fix 3: Update onChange syntax
                .onChange(of: islandDetails.gymWebsite) { oldWebsite, newWebsite in // Use the new signature
                    processWebsiteURL(newWebsite)
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
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
    
    var requiredAddressFields: [AddressFieldType] {
        guard let countryName = selectedCountry?.name.common else {
            return defaultAddressFieldRequirements
        }
        
        return getAddressFieldsSafely(for: countryName)
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

    func getAddressFieldsSafely(for countryCode: String?) -> [AddressFieldType] {
        guard let countryCode = countryCode?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return defaultAddressFieldRequirements
        }
        if let format = countryAddressFormats[countryCode] {
            return format.requiredFields
        } else {
            os_log("⚠️ No specific address format found for %@", countryCode)
            return defaultAddressFieldRequirements
        }
    }


    private func validateForm() {
        // Validate island name
        let islandNameValid = !formState.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        formState.isIslandNameValid = islandNameValid
        formState.islandNameErrorMessage = islandNameValid ? "" : "Gym name cannot be empty."

        var allFieldsValid = true

        for field in requiredAddressFields {
            let value = getValue(for: field)
            let isEmpty = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isEmpty { allFieldsValid = false }

            // Mutate FormState via wrappedValue if it's a Binding
            formState.setErrorMessage(for: field, isEmpty: isEmpty)
        }

        isFormValid = islandNameValid && allFieldsValid
        showValidationMessage = !allFieldsValid && islandNameValid
    }

    private func getErrorMessage(for field: AddressFieldType, country: String) -> String {
        return "\(field.rawValue.capitalized) is required for \(country)."
    }
    

    func updateIslandLocation() async {
        Logger.logCreatedByIdEvent(createdByUserId: profileViewModel.name, fileName: "IslandFormSections", functionName: "updateIslandLocation")

        // Ensure you have the UUID string of the island to update
        // CORRECTED: Access the wrappedValue of islandDetails, then safely unwrap islandID
        guard let islandID = islandDetails.islandID?.uuidString else {
            self.errorMessage = "Island ID is missing for update."
            self.showError = true
            return
        }

        do {
            // Create a dictionary with all the data you want to update in Firestore.
            // The keys in this dictionary should match your Firestore document field names.
            var dataToUpdate: [String: Any] = [
                "name": islandDetails.islandName,
                "location": islandDetails.fullAddress, // Assuming fullAddress is correctly compiled
                "country": selectedCountry?.name.common ?? "Unknown", // Ensure country is included
                "lastModifiedByUserId": profileViewModel.name,
                "lastModifiedTimestamp": Date(), // Always update the timestamp on modification
                // CORRECTED: Provide default values for optional Doubles
                "latitude": islandDetails.latitude ?? 0.0,
                "longitude": islandDetails.longitude ?? 0.0
            ]

            // Conditionally add gymWebsite to avoid issues if it's empty or invalid
            // CORRECTED: Check if the non-optional string is empty
            if !islandDetails.gymWebsite.isEmpty {
                let urlString = islandDetails.gymWebsite.hasPrefix("http")
                    ? islandDetails.gymWebsite
                    : "https://\(islandDetails.gymWebsite)"
                dataToUpdate["gymWebsite"] = urlString
            } else {
                dataToUpdate["gymWebsite"] = NSNull() // Explicitly set to null in Firestore if empty
            }

            // Add all other relevant address fields from islandDetails to the dictionary
            // Make sure these keys match your Firestore document structure
            dataToUpdate["street"] = islandDetails.street
            dataToUpdate["city"] = islandDetails.city
            dataToUpdate["state"] = islandDetails.state
            dataToUpdate["postalCode"] = islandDetails.postalCode
            dataToUpdate["province"] = islandDetails.province
            dataToUpdate["neighborhood"] = islandDetails.neighborhood
            dataToUpdate["complement"] = islandDetails.complement
            dataToUpdate["apartment"] = islandDetails.apartment
            dataToUpdate["region"] = islandDetails.region
            dataToUpdate["county"] = islandDetails.county
            dataToUpdate["governorate"] = islandDetails.governorate
            dataToUpdate["additionalInfo"] = islandDetails.additionalInfo
            dataToUpdate["department"] = islandDetails.department
            dataToUpdate["parish"] = islandDetails.parish
            dataToUpdate["district"] = islandDetails.district
            dataToUpdate["entity"] = islandDetails.entity
            dataToUpdate["municipality"] = islandDetails.municipality
            dataToUpdate["division"] = islandDetails.division
            dataToUpdate["emirate"] = islandDetails.emirate
            dataToUpdate["zone"] = islandDetails.zone
            dataToUpdate["block"] = islandDetails.block
            dataToUpdate["island"] = islandDetails.island
            
            // This is the updated call:
            // It now takes the island's ID as a String and a dictionary of data to update.
            try await viewModel.updatePirateIsland(
                id: islandID,
                data: dataToUpdate
            )

            // Show success message or handle success state
            self.successMessage = "Island location updated successfully!"
            self.showToast = true

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

        // Pass the country's cca2 to validateAddress
        guard validateAddress(for: selectedCountry.cca2) else {
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
    func validateFields() {
        // Skip validation if Gym Name is empty
        if islandDetails.islandName.isEmpty {
            showValidationMessage = false
            return
        }

        let requiredFields = requiredFields(for: selectedCountry)
        var invalidFields: [String] = []

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

            if !isValid {
                // Add the field name to the list of invalid fields
                switch field {
                case .street:
                    invalidFields.append("Street")
                case .city:
                    invalidFields.append("City")
                case .state:
                    invalidFields.append("State")
                case .province:
                    invalidFields.append("Province")
                case .postalCode:
                    invalidFields.append("Postal Code")
                case .region:
                    invalidFields.append("Region")
                case .district:
                    invalidFields.append("District")
                case .department:
                    invalidFields.append("Department")
                case .governorate:
                    invalidFields.append("Governorate")
                case .emirate:
                    invalidFields.append("Emirate")
                case .block:
                    invalidFields.append("Block")
                case .county:
                    invalidFields.append("County")
                case .neighborhood:
                    invalidFields.append("Neighborhood")
                case .complement:
                    invalidFields.append("Complement")
                case .apartment:
                    invalidFields.append("Apartment")
                case .additionalInfo:
                    invalidFields.append("Additional Info")
                case .multilineAddress:
                    invalidFields.append("Multiline Address")
                case .parish:
                    invalidFields.append("Parish")
                case .entity:
                    invalidFields.append("Entity")
                case .municipality:
                    invalidFields.append("Municipality")
                case .division:
                    invalidFields.append("Division")
                case .zone:
                    invalidFields.append("Zone")
                case .island:
                    invalidFields.append("Island")
                }
            }
            
            return isValid
        }

        // Show or hide validation message based on whether the fields are valid
        showValidationMessage = !allValid

        // Display the invalid fields
        if !allValid {
            toastMessage = "The following fields are invalid: \(invalidFields.joined(separator: ", "))"
            showToast = true
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

