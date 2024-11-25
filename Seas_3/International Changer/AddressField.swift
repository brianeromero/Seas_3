//
//  AddressField.swift
//  Seas_3
//
//  Created by Brian Romero on 11/18/24.
//

import Foundation

enum AddressField: String, CaseIterable {
    // Basic address fields
    case street
    case city
    case state
    case province
    case postalCode
    case postcode
    case pincode
    case zip
    
    // Regional fields
    case region
    case district
    case department
    case governorate
    case emirate
    case county
    
    // Additional fields
    case neighborhood
    case complement
    case block
    case apartment
    case additionalInfo
    case multilineAddress
    
    // Country field
    case country
    
    var keyPath: WritableKeyPath<IslandDetails, String> {
        switch self {
        case .street: return \.street
        case .city: return \.city
        case .state: return \.state
        case .province: return \.province
        case .postalCode: return \.postalCode
        case .postcode: return \.postalCode
        case .pincode: return \.pincode
        case .zip: return \.zip
        case .region: return \.region
        case .district: return \.region
        case .department: return \.region
        case .governorate: return \.governorate
        case .emirate: return \.region
        case .county: return \.county
        case .neighborhood: return \.neighborhood
        case .complement: return \.complement
        case .block: return \.block
        case .apartment: return \.apartment
        case .additionalInfo: return \.additionalInfo
        case .multilineAddress: return \.multilineAddress
        case .country: return \.region // Map country to region
        }
    }
}
