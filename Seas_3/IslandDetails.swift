// IslandDetails.swift
// Seas_3
//
// Created by Brian Romero on 11/18/24.

import Foundation
import Combine

class IslandDetails: ObservableObject {
    @Published var islandName: String = ""
    @Published var street: String = ""
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var zip: String = ""
    @Published var gymWebsite: String = ""
    @Published var gymWebsiteURL: URL?
    
    // New address-related fields
    @Published var neighborhood: String = ""
    @Published var complement: String = ""
    @Published var block: String = ""
    @Published var apartment: String = ""
    @Published var region: String = ""
    @Published var county: String = ""
    @Published var governorate: String = ""
    @Published var province: String = ""
    @Published var postalCode: String = ""
    @Published var pincode: String = ""
    
    // Optional Initializer
    init(islandName: String = "",
         street: String = "",
         city: String = "",
         state: String = "",
         zip: String = "",
         gymWebsite: String = "",
         gymWebsiteURL: URL? = nil) {
        self.islandName = islandName
        self.street = street
        self.city = city
        self.state = state
        self.zip = zip
        self.gymWebsite = gymWebsite
        self.gymWebsiteURL = gymWebsiteURL
    }
}
