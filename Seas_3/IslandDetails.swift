// IslandDetails.swift
// Seas_3
//
// Created by Brian Romero on 11/18/24.

import Foundation
import Combine

class IslandDetails: ObservableObject {
    @Published var islandName: String = "" {
        didSet {
            debounceValidation()
        }
    }
    @Published var isIslandNameValid: Bool = true
    @Published var islandNameErrorMessage: String = ""

    @Published var street: String = ""
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var zip: String = ""
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var gymWebsite: String = ""
    @Published var gymWebsiteURL: URL?
    @Published var country: String?
    @Published var multilineAddress: String = ""

    // New address-related fields
    @Published var neighborhood: String = ""
    @Published var complement: String = ""
    @Published var block: String = ""
    @Published var apartment: String = ""
    @Published var region: String = ""
    @Published var county: String = ""
    @Published var governorate: String = ""
    @Published var province: String = ""
    @Published var district: String = ""
    @Published var department: String = ""
    @Published var emirate: String = ""
    @Published var additionalInfo: String = ""

    @Published var postalCode: String = "" {
        didSet {
            // Ensure trimming is done correctly without causing issues
            if postalCode != oldValue {
                postalCode = postalCode.trimmingCharacters(in: .whitespaces)
            }
        }
    }
    
    @Published var pincode: String = "" {
        didSet {
            // Ensure trimming is done correctly without causing issues
            if pincode != oldValue {
                pincode = pincode.trimmingCharacters(in: .whitespaces)
            }
        }
    }
    
    private var validationCancellable: AnyCancellable?
    private let debounceDelay = 0.5 // Delay in seconds

    // Debounce logic for islandName validation
    private func debounceValidation() {
        validationCancellable?.cancel()
        validationCancellable = $islandName
            .debounce(for: .seconds(debounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.validateIslandName(value)
            }
    }

    private func validateIslandName(_ name: String) {
        if name.isEmpty {
            isIslandNameValid = false
            islandNameErrorMessage = "Island name cannot be empty."
        } else {
            isIslandNameValid = true
            islandNameErrorMessage = ""
        }
    }

    // Computed property for full address
    var fullAddress: String {
        """
        \(street)\(neighborhood.isEmpty ? "" : ", \(neighborhood)")\(block.isEmpty ? "" : ", \(block)")\(apartment.isEmpty ? "" : ", Apt \(apartment)")
        \(city)\(region.isEmpty ? "" : ", \(region)")\(state.isEmpty ? "" : ", \(state)")
        \(country ?? "")\(postalCode.isEmpty ? "" : ", \(postalCode)")
        """
    }

    // Optional Initializer
    init(islandName: String = "",
         street: String = "",
         city: String = "",
         state: String = "",
         zip: String = "",
         gymWebsite: String = "",
         gymWebsiteURL: URL? = nil,
         country: String? = nil,
         neighborhood: String = "",
         complement: String = "",
         block: String = "",
         apartment: String = "",
         region: String = "",
         county: String = "",
         governorate: String = "",
         province: String = "",
         postalCode: String = "",
         pincode: String = "") {
        self.islandName = islandName
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.gymWebsite = gymWebsite
        self.gymWebsiteURL = gymWebsiteURL
        self.country = country
        self.neighborhood = neighborhood
        self.complement = complement
        self.block = block
        self.apartment = apartment
        self.region = region
        self.county = county
        self.governorate = governorate
        self.province = province
        self.postalCode = postalCode
        self.pincode = pincode
    }

    // Deinitializer to clean up resources
    deinit {
        validationCancellable?.cancel()
    }
}
