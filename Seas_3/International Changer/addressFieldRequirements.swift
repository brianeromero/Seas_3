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
    case island
}

// Define address field requirements for each region/country
let addressFieldRequirements: [String: [AddressFieldType]] = [
    // Americas
    "AR": [.street, .city, .province, .postalCode], // Argentina
    "BO": [.street, .city, .department], // Bolivia
    "BR": [.street, .neighborhood, .complement, .city, .state, .postalCode], // Brazil
    "CA": [.street, .city, .province, .postalCode], // Canada
    "CL": [.street, .city, .region, .postalCode], // Chile
    "CO": [.street, .city, .department, .postalCode], // Colombia
    "CR": [.street, .city, .province, .postalCode], // Costa Rica
    "CU": [.street, .city, .province, .postalCode], // Cuba
    "DO": [.street, .city, .province, .postalCode], // Dominican Republic
    "EC": [.street, .city, .province, .postalCode], // Ecuador
    "GT": [.street, .city, .department, .postalCode], // Guatemala
    "HN": [.street, .city, .department, .postalCode], // Honduras
    "HT": [.street, .city, .department, .postalCode], // Haiti
    "JM": [.street, .city, .parish, .postalCode], // Jamaica
    "MX": [.street, .city, .state, .postalCode], // Mexico
    "NI": [.street, .city, .department, .postalCode], // Nicaragua
    "PA": [.street, .city, .province, .postalCode], // Panama
    "PE": [.street, .city, .region, .postalCode], // Peru
    "PR": [.street, .city, .state, .postalCode], // Puerto Rico
    "PY": [.street, .city, .department, .postalCode], // Paraguay
    "SR": [.street, .city, .district, .postalCode], // Suriname
    "SV": [.street, .city, .department, .postalCode], // El Salvador
    "TT": [.street, .city, .region, .postalCode], // Trinidad and Tobago
    "US": [.street, .city, .state, .postalCode], // United States
    "UY": [.street, .city, .department, .postalCode], // Uruguay
    "VE": [.street, .city, .state, .postalCode], // Venezuela

    // Europe
    "AD": [.street, .city, .parish, .postalCode], // Andorra
    "AL": [.street, .city, .postalCode], // Albania
    "AM": [.street, .city, .region, .postalCode], // Armenia
    "AT": [.street, .city, .postalCode], // Austria
    "AZ": [.street, .city, .region, .postalCode], // Azerbaijan
    "BA": [.street, .city, .entity, .postalCode], // Bosnia and Herzegovina
    "BE": [.street, .city, .postalCode], // Belgium
    "BG": [.street, .city, .postalCode], // Bulgaria
    "BY": [.street, .city, .region, .postalCode], // Belarus
    "CH": [.street, .city, .postalCode], // Switzerland
    "CY": [.street, .city, .district, .postalCode], // Cyprus
    "CZ": [.street, .city, .postalCode], // Czech Republic
    "DE": [.street, .city, .postalCode], // Germany
    "DK": [.street, .city, .postalCode], // Denmark
    "EE": [.street, .city, .county, .postalCode], // Estonia
    "ES": [.street, .city, .postalCode], // Spain
    "FI": [.street, .city, .postalCode], // Finland
    "FR": [.street, .city, .postalCode], // France
    "GB": [.street, .city, .county, .postalCode], // United Kingdom
    "GE": [.street, .city, .region, .postalCode], // Georgia
    "GR": [.street, .city, .postalCode], // Greece
    "HR": [.street, .city, .county, .postalCode], // Croatia
    "HU": [.street, .city, .postalCode], // Hungary
    "IE": [.street, .city, .county, .postalCode], // Ireland
    "IL": [.street, .city, .district, .postalCode], // Israel
    "IS": [.street, .city, .postalCode], // Iceland
    "IT": [.street, .city, .postalCode], // Italy
    "KZ": [.street, .city, .region, .postalCode], // Kazakhstan
    "LI": [.street, .city, .postalCode], // Liechtenstein
    "LT": [.street, .city, .county, .postalCode], // Lithuania
    "LU": [.street, .city, .postalCode], // Luxembourg
    "LV": [.street, .city, .postalCode], // Latvia
    "MD": [.street, .city, .postalCode], // Moldova
    "ME": [.street, .city, .municipality, .postalCode], // Montenegro
    "MK": [.street, .city, .municipality, .postalCode], // North Macedonia
    "MT": [.street, .city, .postalCode], // Malta
    "NL": [.street, .city, .postalCode], // Netherlands
    "NO": [.street, .city, .postalCode], // Norway
    "PL": [.street, .city, .postalCode], // Poland
    "PT": [.street, .city, .postalCode], // Portugal
    "RO": [.street, .city, .postalCode], // Romania
    "RS": [.street, .city, .municipality, .postalCode], // Serbia
    "RU": [.street, .city, .region, .postalCode, .apartment], // Russia
    "SE": [.street, .city, .postalCode], // Sweden
    "SI": [.street, .city, .postalCode], // Slovenia
    "SK": [.street, .city, .postalCode], // Slovakia
    "SM": [.street, .city, .postalCode], // San Marino
    "TR": [.street, .city, .province, .postalCode], // Turkey
    "UA": [.street, .city, .region, .postalCode], // Ukraine

    // Asia
    "AE": [.street, .city, .emirate, .postalCode], // United Arab Emirates
    "AF": [.street, .city, .province, .postalCode], // Afghanistan
    "BD": [.street, .city, .division, .postalCode], // Bangladesh
    "BH": [.street, .city, .postalCode], // Bahrain
    "BN": [.street, .city, .postalCode], // Brunei
    "BT": [.street, .city, .district, .postalCode], // Bhutan
    "CN": [.street, .city, .province, .postalCode], // China
    "ID": [.street, .city, .province, .postalCode], // Indonesia
    "IN": [.street, .city, .state, .postalCode], // India
    "IQ": [.street, .city, .governorate, .postalCode], // Iraq
    "IR": [.street, .city, .province, .postalCode], // Iran
    "JO": [.street, .city, .governorate, .postalCode], // Jordan
    "JP": [.street, .city, .block], // Japan
    "KG": [.street, .city, .region, .postalCode], // Kyrgyzstan
    "KH": [.street, .city, .province, .postalCode], // Cambodia
    "KP": [.street, .city, .province, .postalCode], // North Korea
    "KR": [.street, .city, .postalCode], // South Korea
    "KW": [.street, .city, .governorate, .postalCode], // Kuwait
    "LA": [.street, .city, .province, .postalCode], // Laos
    "LB": [.street, .city, .governorate, .postalCode], // Lebanon
    "LK": [.street, .city, .district, .postalCode], // Sri Lanka
    "MM": [.street, .city, .division, .postalCode], // Myanmar
    "MN": [.street, .city, .province, .postalCode], // Mongolia
    "MO": [.street, .city, .postalCode], // Macau
    "MV": [.street, .city, .region, .postalCode], // Maldives
    "MY": [.street, .city, .state, .postalCode], // Malaysia
    "NP": [.street, .city, .zone, .postalCode], // Nepal
    "OM": [.street, .city, .province, .postalCode], // Oman
    "PK": [.street, .city, .province, .postalCode], // Pakistan
    "PH": [.street, .city, .province, .postalCode], // Philippines
    "QA": [.street, .city, .postalCode], // Qatar
    "SA": [.street, .city, .province, .postalCode], // Saudi Arabia
    "SG": [.street, .city, .state, .postalCode], // Singapore
    "SY": [.street, .city, .governorate, .postalCode], // Syria
    "TH": [.street, .city, .province, .postalCode], // Thailand
    "TJ": [.street, .city, .region, .postalCode], // Tajikistan
    "TL": [.street, .city, .municipality, .postalCode], // Timor-Leste
    "TM": [.street, .city, .region, .postalCode], // Turkmenistan
    "TN": [.street, .city, .governorate, .postalCode], // Tunisia
    "TW": [.street, .city, .postalCode], // Taiwan
    "UZ": [.street, .city, .region, .postalCode], // Uzbekistan
    "VN": [.street, .city, .province, .postalCode], // Vietnam
    "YE": [.street, .city, .governorate, .postalCode], // Yemen

    // Oceania
    "AU": [.street, .city, .state, .postalCode], // Australia
    "FJ": [.street, .city, .island, .postalCode], // Fiji
    "FM": [.street, .city, .state, .postalCode], // Micronesia
    "KI": [.street, .city, .postalCode], // Kiribati
    "MH": [.street, .city, .island, .postalCode], // Marshall Islands
    "MP": [.street, .city, .postalCode], // Northern Mariana Islands
    "NC": [.street, .city, .province, .postalCode], // New Caledonia
    "NF": [.street, .city, .postalCode], // Norfolk Island
    "NR": [.street, .city, .district, .postalCode], // Nauru
    "NU": [.street, .city, .postalCode], // Niue
    "NZ": [.street, .city, .region, .postalCode], // New Zealand
    "PF": [.street, .city, .island, .postalCode], // French Polynesia
    "PG": [.street, .city, .province, .postalCode], // Papua New Guinea
    "PN": [.street, .city, .postalCode], // Pitcairn Islands
    "PW": [.street, .city, .state, .postalCode], // Palau
    "SB": [.street, .city, .province, .postalCode], // Solomon Islands
    "TK": [.street, .city, .postalCode], // Tokelau
    "TO": [.street, .city, .district, .postalCode], // Tonga
    "TV": [.street, .city, .postalCode], // Tuvalu
    "VU": [.street, .city, .province, .postalCode], // Vanuatu
    "WF": [.street, .city, .postalCode], // Wallis and Futuna
    "WS": [.street, .city, .district, .postalCode] // Samoa
]

// Default address field requirements
let defaultAddressFieldRequirements: [AddressFieldType] = [.street, .city, .state, .postalCode]

// Function to get address field requirements for a country
func getAddressFields(for country: String) -> [AddressFieldType] {
    guard let fields = addressFieldRequirements[country.uppercased()] else {
        print("No address field requirements found for country: \(country). Using default fields.")
        return defaultAddressFieldRequirements
    }
    
    // Log the country and the corresponding fields
    print("Country: \(country), Custom Fields: \(fields.map { $0.rawValue })") // Log custom fields for known countries
    
    return fields
}
    
