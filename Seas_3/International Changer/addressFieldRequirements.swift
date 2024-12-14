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
    case block
    case county
    case neighborhood
    case complement
    case apartment
    case additionalInfo
    case multilineAddress
    case parish
    case entity
    case municipality
    case division
    case zone
    
}

// Define address field requirements for each region/country
let addressFieldRequirements: [String: [AddressFieldType]] = [
    // Americas
    "US": [.street, .city, .state, .postalCode], // USA
    "CA": [.street, .city, .province, .postalCode],  // Canada
    "BR": [.street, .neighborhood, .complement, .city, .state, .postalCode], // Brazil
    "MX": [.street, .city, .state, .postalCode],  // Mexico
    "AR": [.street, .city, .province, .postalCode], // Argentina
    "BO": [.street, .city, .department, .postalCode], // Bolivia
    "CL": [.street, .city, .region, .postalCode], // Chile
    "CO": [.street, .city, .department, .postalCode], // Colombia
    "CR": [.street, .city, .province, .postalCode], // Costa Rica
    "CU": [.street, .city, .province, .postalCode], // Cuba
    "DO": [.street, .city, .province, .postalCode], // Dominican Republic
    "EC": [.street, .city, .province, .postalCode], // Ecuador
    "SV": [.street, .city, .department, .postalCode], // El Salvador
    "GT": [.street, .city, .department, .postalCode], // Guatemala
    "HT": [.street, .city, .department, .postalCode], // Haiti
    "HN": [.street, .city, .department, .postalCode], // Honduras
    "JM": [.street, .city, .parish, .postalCode], // Jamaica
    "NI": [.street, .city, .department, .postalCode], // Nicaragua
    "PA": [.street, .city, .province, .postalCode], // Panama
    "PY": [.street, .city, .department, .postalCode], // Paraguay
    "PE": [.street, .city, .region, .postalCode], // Peru
    "PR": [.street, .city, .state, .postalCode], // Puerto Rico
    "SR": [.street, .city, .district, .postalCode], // Suriname
    "TT": [.street, .city, .region, .postalCode], // Trinidad and Tobago
    "UY": [.street, .city, .department, .postalCode], // Uruguay
    "VE": [.street, .city, .state, .postalCode], // Venezuela

    // Europe
    "GB": [.street, .city, .county, .postalCode], // United Kingdom
    "IE": [.street, .city, .county, .postalCode], // Ireland
    "FR": [.street, .city, .postalCode], // France
    "DE": [.street, .city, .postalCode], // Germany
    "ES": [.street, .city, .postalCode], // Spain
    "IT": [.street, .city, .postalCode], // Italy
    "NL": [.street, .city, .postalCode], // Netherlands
    "BE": [.street, .city, .postalCode], // Belgium
    "SE": [.street, .city, .postalCode], // Sweden
    "NO": [.street, .city, .postalCode], // Norway
    "CH": [.street, .city, .postalCode], // Switzerland
    "PL": [.street, .city, .postalCode], // Poland
    "AT": [.street, .city, .postalCode], // Austria
    "PT": [.street, .city, .postalCode], // Portugal
    "DK": [.street, .city, .postalCode], // Denmark
    "FI": [.street, .city, .postalCode], // Finland
    "RU": [.street, .city, .region, .postalCode, .apartment], // Russia
    "GR": [.street, .city, .postalCode], // Greece
    "CZ": [.street, .city, .postalCode], // Czech Republic
    "HU": [.street, .city, .postalCode], // Hungary
    "RO": [.street, .city, .postalCode], // Romania
    "AL": [.street, .city, .postalCode], // Albania
    "AD": [.street, .city, .parish, .postalCode], // Andorra
    "AM": [.street, .city, .region, .postalCode], // Armenia
    "AZ": [.street, .city, .region, .postalCode], // Azerbaijan
    "BY": [.street, .city, .region, .postalCode], // Belarus
    "BA": [.street, .city, .entity, .postalCode], // Bosnia and Herzegovina
    "BG": [.street, .city, .postalCode], // Bulgaria
    "HR": [.street, .city, .county, .postalCode], // Croatia
    "CY": [.street, .city, .district, .postalCode], // Cyprus
    "EE": [.street, .city, .county, .postalCode], // Estonia
    "GE": [.street, .city, .region, .postalCode], // Georgia
    "IS": [.street, .city, .postalCode], // Iceland
    "KZ": [.street, .city, .region, .postalCode], // Kazakhstan
    "XK": [.street, .city, .district, .postalCode], // Kosovo
    "LV": [.street, .city, .postalCode], // Latvia
    "LI": [.street, .city, .postalCode], // Liechtenstein
    "LT": [.street, .city, .county, .postalCode], // Lithuania
    "LU": [.street, .city, .postalCode], // Luxembourg
    "MT": [.street, .city, .postalCode], // Malta
    "MD": [.street, .city, .postalCode], // Moldova
    "MC": [.street, .city, .postalCode], // Monaco
    "ME": [.street, .city, .municipality, .postalCode], // Montenegro
    "MK": [.street, .city, .municipality, .postalCode], // North Macedonia
    "SM": [.street, .city, .postalCode], // San Marino
    "RS": [.street, .city, .municipality, .postalCode], // Serbia
    "SK": [.street, .city, .postalCode], // Slovakia
    "SI": [.street, .city, .postalCode], // Slovenia
    "TR": [.street, .city, .province, .postalCode], // Turkey
    "UA": [.street, .city, .region, .postalCode], // Ukraine

    // Asia
    "CN": [.street, .city, .province, .postalCode], // China
    "JP": [.street, .city, .block], // Japan
    "IN": [.street, .city, .state, .postalCode], // India
    "KR": [.street, .city, .postalCode], // Korea
    "AF": [.street, .city, .province, .postalCode], // Afghanistan
    "BH": [.street, .city, .postalCode], // Bahrain
    "BD": [.street, .city, .division, .postalCode], // Bangladesh
    "BT": [.street, .city, .district, .postalCode], // Bhutan
    "BN": [.street, .city, .postalCode], // Brunei
    "KH": [.street, .city, .province, .postalCode], // Cambodia
    "TL": [.street, .city, .municipality, .postalCode], // Timor-Leste
    "ID": [.street, .city, .province, .postalCode], // Indonesia
    "IR": [.street, .city, .province, .postalCode], // Iran
    "IQ": [.street, .city, .governorate, .postalCode], // Iraq
    "IL": [.street, .city, .district, .postalCode], // Israel
    "JO": [.street, .city, .governorate, .postalCode], // Jordan
    "KW": [.street, .city, .governorate, .postalCode], // Kuwait
    "KG": [.street, .city, .region, .postalCode], // Kyrgyzstan
    "LA": [.street, .city, .province, .postalCode], // Laos
    "LB": [.street, .city, .governorate, .postalCode], // Lebanon
    "MY": [.street, .city, .state, .postalCode], // Malaysia
    "MV": [.street, .city, .region, .postalCode], // Maldives
    "MM": [.street, .city, .division, .postalCode], // Myanmar
    "MN": [.street, .city, .province, .postalCode], // Mongolia
    "NP": [.street, .city, .zone, .postalCode], // Nepal
    "OM": [.street, .city, .province, .postalCode], // Oman
    "PK": [.street, .city, .province, .postalCode], // Pakistan
    "QA": [.street, .city, .postalCode], // Qatar
    "SA": [.street, .city, .province, .postalCode], // Saudi Arabia
    "SG": [.street, .city, .state, .postalCode], // Singapore
    "LK": [.street, .city, .district, .postalCode], // Sri Lanka
    "SY": [.street, .city, .governorate, .postalCode], // Syria
    "TW": [.street, .city, .postalCode], // Taiwan
    "TH": [.street, .city, .province, .postalCode], // Thailand
    "UZ": [.street, .city, .region, .postalCode], // Uzbekistan
    "AE": [.street, .city, .emirate, .postalCode], // United Arab Emirates
    "VN": [.street, .city, .province, .postalCode],  // Vietnam

    // Oceania
    "AU": [.street, .city, .state, .postalCode], // Australia
    "FM": [.street, .city, .state, .postalCode], // Micronesia
    "NR": [.street, .city, .district, .postalCode], // Nauru
    "NU": [.street, .city, .postalCode], // Niue
    "NF": [.street, .city, .postalCode], // Norfolk Island
    "MP": [.street, .city, .postalCode], // Northern Mariana Islands
    "PW": [.street, .city, .state, .postalCode], // Palau
    "PG": [.street, .city, .province, .postalCode], // Papua New Guinea
    "PN": [.street, .city, .postalCode], // Pitcairn Islands
    "SB": [.street, .city, .province, .postalCode], // Solomon Islands
    "TK": [.street, .city, .postalCode], // Tokelau
    "TO": [.street, .city, .district, .postalCode], // Tonga
    "TV": [.street, .city, .postalCode], // Tuvalu
    "VU": [.street, .city, .province, .postalCode], // Vanuatu
    "WF": [.street, .city, .postalCode], // Wallis and Futuna
    "WS": [.street, .city, .district, .postalCode], // Samoa
    "KI": [.street, .city, .postalCode], // Kiribati
    "PH": [.street, .city, .province, .postalCode] // Philippines

    
    // Additional countries

]

// Default address field requirements
/// Used when country-specific requirements are not available
let defaultAddressFieldRequirements: [AddressFieldType] = [.street, .city, .state, .postalCode]

// Function to get address field requirements for a country
func getAddressFields(for country: String) -> [AddressFieldType] {
    guard let fields = addressFieldRequirements[country] else {
        print("No address field requirements found for country: \(country). Using default fields.")
        return defaultAddressFieldRequirements
    }
    
    // Log the country and the corresponding fields
    print("Country: \(country), Custom Fields: \(fields.map { $0.rawValue })") // Log custom fields for known countries
    
    return fields
}
