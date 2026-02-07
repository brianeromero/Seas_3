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

    // Bindings
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

    // Alerts and Toasts
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isPickerPresented = false
    @State private var successMessage: String? = nil
    @State private var showErrorAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""

    // Validation bindings
    @Binding var isSaveEnabled: Bool
    @Binding var showValidationMessage: Bool
    @Binding var missingFields: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            countryPickerSection
            islandDetailsSection
            websiteSection
        }
        .padding(.horizontal)
        .padding(.top)
        .onAppear {
            Task { await countryService.fetchCountries() }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Country Picker
    @ViewBuilder
    var countryPickerSection: some View {
        if countryService.isLoading {
            ProgressView("Loading countries...")
        } else if countryService.countries.isEmpty {
            Text("No countries found.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            UnifiedCountryPickerView(
                countryService: countryService,
                selectedCountry: $selectedCountry,
                isPickerPresented: $isPickerPresented
            )
            .onChange(of: selectedCountry) { oldCountry, newCountry in
                guard newCountry?.cca2 != islandDetails.country else { return }
                islandDetails.country = newCountry?.cca2 ?? ""
                updateAddressRequirements(for: newCountry)
                
                if newCountry?.cca2 != "US" {
                    islandDetails.state = ""
                } else if !USStates.allCodes.contains(islandDetails.state) {
                    islandDetails.state = ""
                }
            }
        }
    }

    // MARK: - Island Details Section
    var islandDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gym Name").font(.headline)
            TextField("Enter Gym Name", text: validatedBinding(for: \.islandName))
            
            let requiredFields = requiredFields(for: selectedCountry)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(requiredFields, id: \.self) { field in
                    addressField(for: field)
                }
            }
            .padding(.top)
        }
    }
    
    private func getMissingRequiredFields(for country: Country?) -> [String] {
        let required = requiredFields(for: country)
        return required.compactMap { field in
            let value = getValue(for: field).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? field.rawValue : nil
        }
    }

    // MARK: - Address Field Dynamic Generation
    @ViewBuilder
    func addressField(for field: AddressFieldType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch field {
            case .street:
                TextField("Street", text: $islandDetails.street)
            case .city:
                TextField("City", text: $islandDetails.city)
            case .state:
                if selectedCountry?.cca2 == "US" {
                    Picker("State", selection: $islandDetails.state) {
                        Text("Select State").tag("")
                        ForEach(USStates.allCodes.sorted(), id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                } else {
                    TextField("State / Province / Region", text: $islandDetails.state)
                }
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
                TextField("Department", text: $islandDetails.department)
            case .parish:
                TextField("Parish", text: $islandDetails.parish)
            case .district:
                TextField("District", text: $islandDetails.district)
            case .entity:
                TextField("Entity", text: $islandDetails.entity)
            case .municipality:
                TextField("Municipality", text: $islandDetails.municipality)
            case .division:
                TextField("Division", text: $islandDetails.division)
            case .emirate:
                TextField("Emirate", text: $islandDetails.emirate)
            case .zone:
                TextField("Zone", text: $islandDetails.zone)
            case .block:
                TextField("Block", text: $islandDetails.block)
            default:
                EmptyView()
            }

            // Validation message
            if showValidationMessage && missingFields.contains(field.rawValue) {
                Text("\(field.displayName) is required")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Website Section
    var websiteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instagram/Facebook/Website").font(.headline)
            TextField("Enter Website", text: validatedBinding(for: \.gymWebsite))
                .onChange(of: islandDetails.gymWebsite) { _, newWebsite in
                    processWebsiteURL(newWebsite)
                }
        }
    }

    private func getValue(for field: AddressFieldType) -> String {
        switch field {
        case .street: return islandDetails.street
        case .city: return islandDetails.city
        case .state: return islandDetails.state
        case .postalCode: return islandDetails.postalCode
        case .province: return islandDetails.province
        case .neighborhood: return islandDetails.neighborhood
        case .complement: return islandDetails.complement
        case .apartment: return islandDetails.apartment
        case .region: return islandDetails.region
        case .county: return islandDetails.county
        case .governorate: return islandDetails.governorate
        case .additionalInfo: return islandDetails.additionalInfo
        case .department: return islandDetails.department
        case .parish: return islandDetails.parish
        case .district: return islandDetails.district
        case .entity: return islandDetails.entity
        case .municipality: return islandDetails.municipality
        case .division: return islandDetails.division
        case .emirate: return islandDetails.emirate
        case .zone: return islandDetails.zone
        case .block: return islandDetails.block
        case .island: return islandDetails.island
        default: return ""
        }
    }

    func processWebsiteURL(_ url: String) {
        guard !url.isEmpty else {
            islandDetails.gymWebsiteURL = nil
            return
        }
        let sanitized = "https://" + url.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
        if let validURL = URL(string: sanitized) {
            islandDetails.gymWebsiteURL = validURL
        } else {
            errorMessage = "Invalid URL format"
            showError = true
        }
    }

    private func validateForm() {
        let missing = getMissingRequiredFields(for: selectedCountry)
        showValidationMessage = !missing.isEmpty
        missingFields = missing

        isSaveEnabled =
            missing.isEmpty &&
            !islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func validatedBinding(for keyPath: WritableKeyPath<IslandDetails, String>) -> Binding<String> {
        Binding(
            get: { islandDetails[keyPath: keyPath] },
            set: { newValue in
                islandDetails[keyPath: keyPath] = newValue
                validateForm()
            }
        )
    }

    // MARK: - Address Fields
    func requiredFields(for country: Country?) -> [AddressFieldType] {
        guard let code = country?.cca2.uppercased() else {
            return defaultAddressFieldRequirements
        }
        return countryAddressFormats[code]?.requiredFields ?? defaultAddressFieldRequirements
    }

    private func updateAddressRequirements(for country: Country?) {
        islandDetails.requiredAddressFields = requiredFields(for: country)
    }

    func binding(for field: AddressField) -> Binding<String> {
        switch field {
        case .street: return $islandDetails.street
        case .city: return $islandDetails.city
        case .postalCode: return $islandDetails.postalCode
        case .state: return $islandDetails.state
        case .province: return $islandDetails.province
        case .region, .county, .governorate: return $islandDetails.region
        case .neighborhood: return $islandDetails.neighborhood
        case .complement: return $islandDetails.complement
        case .apartment: return $islandDetails.apartment
        case .additionalInfo: return $islandDetails.additionalInfo
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

