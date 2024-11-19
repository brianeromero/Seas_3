//
//  addressFieldRequirements.swift
//  Seas_3
//

import Foundation

// Define address field types
enum AddressFieldType: String {
    case street
    case city
    case state
    case province
    case postalCode
    case region
    case district
    case department
    case governorate
    case emirate
    case postcode
    case pincode
    case block
    case county
    case zip
    case neighborhood  // For Brazil
    case complement    // For Brazil
    case apartment     // For Russia and other countries with unit-level addresses
    case additionalInfo // For Saudi Arabia's Additional Number
    case multilineAddress // General field for multiline formatting
}


// Define address field requirements for each region/country
let addressFieldRequirements: [String: [AddressFieldType]] = [
    
    // Americas
    "US": [.street, .city, .state, .postalCode],
    "CA": [.street, .city, .province, .postalCode],
    "BR": [.street, .neighborhood, .complement, .city, .state, .postalCode], // For Brazil
    "MX": [.street, .city, .state, .postalCode],
    
    // Europe
    "GB": [.street, .city, .postcode],  // United Kingdom
    "IE": [.street, .city, .county, .postalCode],  // Ireland (Republic of Ireland)
    "FR": [.street, .city, .postalCode],  // France
    "DE": [.street, .city, .postalCode],  // Germany
    "ES": [.street, .city, .postalCode],  // Spain
    "IT": [.street, .city, .postalCode],  // Italy
    "NL": [.street, .city, .postalCode],  // Netherlands
    "BE": [.street, .city, .postalCode],  // Belgium
    "SE": [.street, .city, .postalCode],  // Sweden
    "NO": [.street, .city, .postalCode],  // Norway
    "CH": [.street, .city, .postalCode],  // Switzerland
    "PL": [.street, .city, .postalCode],  // Poland
    "AT": [.street, .city, .postalCode],  // Austria
    "PT": [.street, .city, .postalCode],  // Portugal
    "DK": [.street, .city, .postalCode],  // Denmark
    "FI": [.street, .city, .postalCode],  // Finland
    "RU": [.street, .city, .region, .postalCode, .apartment], // Russia
    "GR": [.street, .city, .postalCode],  // Greece
    "CZ": [.street, .city, .postalCode],  // Czech Republic
    "HU": [.street, .city, .postalCode],  // Hungary
    "RO": [.street, .city, .postalCode],  // Romania
    
    // Asia
    "CN": [.street, .city, .province, .postalCode],
    "JP": [.street, .city, .block],
    "IN": [.street, .city, .state, .pincode],
    "KR": [.street, .city, .postalCode],
    
    // Africa
    "EG": [.street, .city, .governorate, .postalCode],
    "ZA": [.street, .city, .province, .postalCode],
    "NG": [.street, .city, .state, .postalCode],
    
    // Oceania
    "AU": [.street, .city, .state, .postalCode],

    // Additional countries
    "AE": [.street, .city, .emirate, .postalCode],
    "IL": [.street, .city, .district, .postalCode],
    "CL": [.street, .city, .region, .postalCode],
    "CO": [.street, .city, .department, .postalCode],
    "TR": [.street, .city, .province, .postalCode],
    "TH": [.street, .city, .province, .postalCode],
    "SA": [.street, .city, .province, .postalCode, .additionalInfo], // Saudi Arabia
    "PK": [.street, .city, .province, .postalCode],
    "VN": [.street, .city, .province, .postalCode],
    "PH": [.street, .city, .province, .postalCode],
    "ID": [.street, .city, .province, .postalCode],
    "AR": [.street, .city, .province, .postalCode]
    
]

// Default address field requirements
/// Used when country-specific requirements are not available
let defaultAddressFieldRequirements: [AddressFieldType] = [.street, .city, .state, .postalCode]

// Function to get address field requirements for a country
func getAddressFields(for country: String) -> [AddressFieldType] {
    let fields = addressFieldRequirements[country] ?? defaultAddressFieldRequirements
    
    // Log the country and the corresponding fields
    if addressFieldRequirements[country] != nil {
        print("Country: \(country), Custom Fields: \(fields.map { $0.rawValue })") // Log custom fields for known countries
    } else {
        print("Country: \(country), Using Default Fields: \(fields.map { $0.rawValue })") // Log default fields
    }
    
    return fields
}
