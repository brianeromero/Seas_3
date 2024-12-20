//
//  IslandDetails.swift
//  Seas_3
//

import Foundation
import Combine
import Foundation
import Combine

class IslandDetails: ObservableObject, Equatable {
    // MARK: - Published Properties
    @Published var islandName: String = "" { didSet { validateForm() } }
    @Published var street: String = "" { didSet { validateForm() } }
    @Published var city: String = "" { didSet { validateForm() } }
    @Published var state: String = "" { didSet { validateForm() } }
    @Published var postalCode: String = "" { didSet { validateForm() } }
    @Published var requiredAddressFields: [AddressFieldType] = []
    
    @Published var selectedCountry: Country? {
        didSet {
            updateRequiredAddressFields()
        }
    }
    
    @Published var gymWebsite: String = "" { didSet { validateForm() } }
    @Published var gymWebsiteURL: URL?

    @Published var neighborhood: String = ""
    @Published var complement: String = ""
    @Published var block: String = ""
    @Published var apartment: String = ""
    @Published var region: String = ""
    @Published var country: String = ""
    @Published var county: String = ""
    @Published var governorate: String = ""
    @Published var province: String = ""
    @Published var district: String = ""
    @Published var department: String = ""
    @Published var emirate: String = ""
    @Published var parish: String = ""
    @Published var entity: String = ""
    @Published var municipality: String = ""
    @Published var division: String = ""
    @Published var zone: String = ""
    @Published var island: String = ""


    // MARK: - Validation Properties
    @Published var isIslandNameValid: Bool = true
    @Published var islandNameErrorMessage: String = ""
    @Published var isFormValid: Bool = false

    // Callback to notify parent views of validation state
    var onValidationChange: ((Bool) -> Void)?

    // MARK: - Other Properties
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var multilineAddress: String = ""
    @Published var additionalInfo: String = ""


    // MARK: - Computed Properties
    var islandLocation: String {
        let locationComponents = requiredAddressFields.compactMap { field -> String? in
            switch field {
            case .street: return street
            case .city: return city
            case .state: return state
            case .postalCode: return postalCode
            case .county: return county
            case .parish: return parish
            case .entity: return entity
            case .municipality: return municipality
            case .division: return division
            case .zone: return zone
            case .island: return island
            default: return nil
            }
        }
        return locationComponents.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var fullAddress: String {
        var address = [islandLocation]
        if !country.isEmpty {
            address.append(country)
        }
        if let selectedCountry = selectedCountry, !selectedCountry.name.common.isEmpty {
            address.append(selectedCountry.name.common)
        }
        return address.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    // MARK: - Initializer
    init(islandName: String = "",
         street: String = "",
         city: String = "",
         state: String = "",
         postalCode: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         selectedCountry: Country? = nil,
         country: String = "",
         county: String = "",
         additionalInfo: String = "",
         requiredAddressFields: [AddressFieldType] = [],
         gymWebsite: String = "",
         gymWebsiteURL: URL? = nil) {
        self.islandName = islandName
        self.street = street
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.latitude = latitude
        self.longitude = longitude
        self.selectedCountry = selectedCountry
        self.country = country
        self.county = county
        self.additionalInfo = additionalInfo
        self.requiredAddressFields = requiredAddressFields
        self.gymWebsite = gymWebsite
        self.gymWebsiteURL = gymWebsiteURL
        validateForm()
    }

    // MARK: - Validation Logic
    private func validateForm() {
        let fieldsValid = requiredAddressFields.allSatisfy { field in
            switch field {
            case .street: return !street.isEmpty
            case .city: return !city.isEmpty
            case .state: return !state.isEmpty
            case .province: return !province.isEmpty
            case .postalCode: return !postalCode.isEmpty
            case .region: return !region.isEmpty
            case .district: return !district.isEmpty
            case .department: return !department.isEmpty
            case .governorate: return !governorate.isEmpty
            case .emirate: return !emirate.isEmpty
            case .block: return !block.isEmpty
            case .county: return !county.isEmpty
            case .neighborhood: return !neighborhood.isEmpty
            case .complement: return !complement.isEmpty
            case .apartment: return !apartment.isEmpty
            case .additionalInfo: return !additionalInfo.isEmpty
            case .multilineAddress: return !multilineAddress.isEmpty
            case .parish: return !islandName.isEmpty
            case .entity: return !islandName.isEmpty
            case .municipality: return !islandName.isEmpty
            case .division: return !islandName.isEmpty
            case .zone: return !islandName.isEmpty
            case .island: return !island.isEmpty
            }
        }
        let islandNameValid = !islandName.isEmpty
        isIslandNameValid = islandNameValid
        islandNameErrorMessage = islandNameValid ? "" : "Gym name cannot be empty."
        
        let formValid = fieldsValid && islandNameValid
        isFormValid = formValid
        onValidationChange?(formValid)
    }

    // MARK: - Update Required Address
    func updateRequiredAddressFields() {
        guard let countryName = selectedCountry?.name.common else {
            requiredAddressFields = defaultAddressFieldRequirements
            return
        }
        
        requiredAddressFields = getAddressFields(for: countryName)
        validateForm()
    }

    // MARK: - Equatable Protocol
    static func == (lhs: IslandDetails, rhs: IslandDetails) -> Bool {
        lhs.islandName == rhs.islandName &&
        lhs.street == rhs.street &&
        lhs.city == rhs.city &&
        lhs.state == rhs.state &&
        lhs.postalCode == rhs.postalCode &&
        lhs.selectedCountry?.cca2 == rhs.selectedCountry?.cca2 &&
        lhs.latitude == rhs.latitude &&
        lhs.longitude == rhs.longitude &&
        lhs.additionalInfo == rhs.additionalInfo &&
        lhs.country == rhs.country &&
        lhs.county == rhs.county &&
        lhs.island == rhs.island
    }
}

