//
//  AddressField.swift
//  Mat_Finder
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
    
    // Regional fields
    case region
    case district
    case department
    case governorate
    case emirate
    case county
    case parish
    case entity
    case municipality
    case division
    case zone
    
    // Additional fields
    case neighborhood
    case complement
    case block
    case apartment
    case additionalInfo
    case multilineAddress
    case island

    
    // Country field
    case country
    
    var keyPath: WritableKeyPath<IslandDetails, String> {
        switch self {
        case .street: return \.street
        case .city: return \.city
        case .state: return \.state
        case .province: return \.province
        case .postalCode: return \.postalCode
        case .region: return \.region
        case .district: return \.region
        case .department: return \.region
        case .governorate: return \.governorate
        case .emirate: return \.region
        case .county: return \.county
        case .parish: return \.region
        case .entity: return \.region
        case .municipality: return \.region
        case .division: return \.region
        case .zone: return \.region
        case .neighborhood: return \.neighborhood
        case .complement: return \.complement
        case .block: return \.block
        case .apartment: return \.apartment
        case .additionalInfo: return \.additionalInfo
        case .multilineAddress: return \.multilineAddress
        case .country: return \.region
        case .island: return \.islandName
        }
    }
}
