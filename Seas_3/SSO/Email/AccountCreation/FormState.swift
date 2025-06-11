//
//  FormState.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import SwiftUI

public struct FormState { // Add 'public' here
    // User Information
    var userName: String = "" {
        didSet { validateField(userName, type: .userName) }
    }
    var isUserNameValid: Bool = false
    var userNameErrorMessage: String = ""

    var name: String = "" {
        didSet { validateField(name, type: .name) }
    }
    var isNameValid: Bool = false
    var nameErrorMessage: String = ""

    var email: String = "" {
        didSet { validateField(email, type: .email) }
    }
    var isEmailValid: Bool = false
    var emailErrorMessage: String = ""

    // Password
    var password: String = "" {
        didSet { validateField(password, type: .password) }
    }
    var isPasswordValid: Bool = false
    var passwordErrorMessage: String = ""

    var confirmPassword: String = "" {
        didSet { validateConfirmPassword() }
    }
    var isConfirmPasswordValid: Bool = false
    var confirmPasswordErrorMessage: String = ""

    // Address Information
    var islandName: String = "" {
        didSet { validateField(islandName, type: .name) }
    }
    var isIslandNameValid: Bool = false
    var islandNameErrorMessage: String = ""

    var street: String = "" {
        didSet { validateField(street, type: .name) }
    }
    var isStreetValid: Bool = false
    var streetErrorMessage: String = ""

    var city: String = "" {
        didSet { validateField(city, type: .name) }
    }
    var isCityValid: Bool = false
    var cityErrorMessage: String = ""

    var state: String = "" {
        didSet { validateField(state, type: .name) }
    }
    var isStateValid: Bool = false
    var stateErrorMessage: String = ""
    
    var selectedCountry: Country? // Where `Country` is a type you've defined or imported.

    var postalCode: String = "" {
        didSet { validateField(postalCode, type: .name) }
    }
    var isPostalCodeValid: Bool = false
    var postalCodeErrorMessage: String = ""

    var province: String = "" {
        didSet { validateField(province, type: .name) }
    }
    var isProvinceValid: Bool = false
    var provinceErrorMessage: String = ""

    var region: String = "" {
        didSet { validateField(region, type: .name) }
    }
    var isRegionValid: Bool = false
    var regionErrorMessage: String = ""

    var district: String = "" {
        didSet { validateField(district, type: .name) }
    }
    var department: String = "" {
        didSet { validateField(department, type: .name) }
    }
    var isDepartmentValid: Bool = false
    var departmentErrorMessage: String = ""

    var governorate: String = "" {
        didSet { validateField(governorate, type: .name) }
    }
    var isGovernorateValid: Bool = false
    var governorateErrorMessage: String = ""

    var emirate: String = "" {
        didSet { validateField(emirate, type: .name) }
    }
    var isEmirateValid: Bool = false
    var emirateErrorMessage: String = ""

    var county: String = "" {
        didSet { validateField(county, type: .name) }
    }
    var isCountyValid: Bool = false
    var countyErrorMessage: String = ""

    var neighborhood: String = "" {
        didSet { validateField(neighborhood, type: .name) }
    }
    var isNeighborhoodValid: Bool = false
    var neighborhoodErrorMessage: String = ""

    var complement: String = "" {
        didSet { validateField(complement, type: .name) }
    }
    var isComplementValid: Bool = false
    var complementErrorMessage: String = ""

    var block: String = "" {
        didSet { validateField(block, type: .name) }
    }
    var isBlockValid: Bool = false
    var blockErrorMessage: String = ""

    var apartment: String = "" {
        didSet { validateField(apartment, type: .name) }
    }
    var isApartmentValid: Bool = false
    var apartmentErrorMessage: String = ""

    var additionalInfo: String = "" {
        didSet { validateField(additionalInfo, type: .name) }
    }
    var isAdditionalInfoValid: Bool = false
    var additionalInfoErrorMessage: String = ""

    var multilineAddress: String = "" {
        didSet { validateField(multilineAddress, type: .name) }
    }
    var isMultilineAddressValid: Bool = false
    var multilineAddressErrorMessage: String = ""

    var parish: String = "" {
        didSet { validateField(parish, type: .name) }
    }
    var isParishValid: Bool = false
    var parishErrorMessage: String = ""

    var municipality: String = "" {
        didSet { validateField(municipality, type: .name) }
    }
    var isMunicipalityValid: Bool = false
    var municipalityErrorMessage: String = ""

    var division: String = "" {
        didSet { validateField(division, type: .name) }
    }
    var isDivisionValid: Bool = false
    var divisionErrorMessage: String = ""

    var zone: String = "" {
        didSet { validateField(zone, type: .name) }
    }
    var isZoneValid: Bool = false
    var zoneErrorMessage: String = ""

    var island: String = "" {
        didSet { validateField(island, type: .name) }
    }
    
    var isIslandValid: Bool = false
    var islandErrorMessage: String = ""

    var country: String = "" {
        didSet { validateField(country, type: .name) }
    }
    var isCountryValid: Bool = false
    var countryErrorMessage: String = ""
    
    var isDistrictValid: Bool = false
    var districtErrorMessage: String = ""
    
    
    var entity: String = "" {
        didSet { validateField(entity, type: .name) }
    }
    var isEntityValid: Bool = false
    var entityErrorMessage: String = ""
    

    // Gym Website Information
    var gymWebsite: String = "" {
        didSet { validateField(gymWebsite, type: .name) }
    }
    var isGymWebsiteValid: Bool = false
    var gymWebsiteErrorMessage: String = ""

    var gymWebsiteURL: String = "" {
        didSet { validateField(gymWebsiteURL, type: .name) }
    }
    var isGymWebsiteURLValid: Bool = false
    var gymWebsiteURLErrorMessage: String = ""

    var showAlert: Bool = false
    var alertMessage: String = ""

    var isValid: Bool {
        // Check required fields
        let basicValidations = [
            isUserNameValid,
            isNameValid,
            isEmailValid,
            isPasswordValid,
            isConfirmPasswordValid
        ].allSatisfy { $0 }
        
        // If island name is provided, the following fields must also be valid
        let islandRelatedValidations = (isIslandNameValid ? [
            isStreetValid,
            isCityValid,
            isStateValid,
            isPostalCodeValid,
            isProvinceValid,
            isRegionValid,
            isDistrictValid
        ].allSatisfy { $0 } : true)

        // Gym website fields can be validated, but aren't required
        let gymWebsiteValidations = [
            isGymWebsiteValid,
            isGymWebsiteURLValid
        ].allSatisfy { $0 }
        
        // Additional address fields validation
        let additionalAddressValidations = [
            isDepartmentValid,
            isGovernorateValid,
            isEmirateValid,
            isCountyValid,
            isNeighborhoodValid,
            isComplementValid,
            isBlockValid,
            isApartmentValid,
            isAdditionalInfoValid,
            isMultilineAddressValid,
            isParishValid,
            isMunicipalityValid,
            isDivisionValid,
            isZoneValid,
            isIslandValid,
            isCountryValid,
            isEntityValid
        ].allSatisfy { $0 }
        
        // Combine all validations, excluding selectedProtocol
        return basicValidations && islandRelatedValidations && gymWebsiteValidations && additionalAddressValidations
    }

    // Validation functions
    mutating func validateField(_ field: String, type: ValidationType) {
        if let error = ValidationUtility.validateField(field, type: type) {
            switch type {
            case .userName:
                isUserNameValid = false
                userNameErrorMessage = error.rawValue
            case .name:
                if field == name {
                    isNameValid = false
                    nameErrorMessage = error.rawValue
                } else if field == islandName {
                    isIslandNameValid = false
                    islandNameErrorMessage = error.rawValue
                } else if field == street {
                    isStreetValid = false
                    streetErrorMessage = error.rawValue
                } else if field == city {
                    isCityValid = false
                    cityErrorMessage = error.rawValue
                } else if field == state {
                    isStateValid = false
                    stateErrorMessage = error.rawValue
                } else if field == postalCode {
                    isPostalCodeValid = false
                    postalCodeErrorMessage = error.rawValue
                } else if field == gymWebsite {
                    isGymWebsiteValid = false
                    gymWebsiteErrorMessage = error.rawValue
                } else if field == gymWebsiteURL {
                    isGymWebsiteURLValid = false
                    gymWebsiteURLErrorMessage = error.rawValue
                } else if field == province {
                    isProvinceValid = false
                    provinceErrorMessage = error.rawValue
                } else if field == region {
                    isRegionValid = false
                    regionErrorMessage = error.rawValue
                } else if field == district {
                    isDistrictValid = false
                    districtErrorMessage = error.rawValue
                } else if field == department {
                    isDepartmentValid = false
                    departmentErrorMessage = error.rawValue
                } else if field == governorate {
                    isGovernorateValid = false
                    governorateErrorMessage = error.rawValue
                } else if field == emirate {
                    isEmirateValid = false
                    emirateErrorMessage = error.rawValue
                } else if field == county {
                    isCountyValid = false
                    countyErrorMessage = error.rawValue
                } else if field == neighborhood {
                    isNeighborhoodValid = false
                    neighborhoodErrorMessage = error.rawValue
                } else if field == complement {
                    isComplementValid = false
                    complementErrorMessage = error.rawValue
                } else if field == block {
                    isBlockValid = false
                    blockErrorMessage = error.rawValue
                } else if field == apartment {
                    isApartmentValid = false
                    apartmentErrorMessage = error.rawValue
                } else if field == additionalInfo {
                    isAdditionalInfoValid = false
                    additionalInfoErrorMessage = error.rawValue
                } else if field == multilineAddress {
                    isMultilineAddressValid = false
                    multilineAddressErrorMessage = error.rawValue
                } else if field == parish {
                    isParishValid = false
                    parishErrorMessage = error.rawValue
                } else if field == municipality {
                    isMunicipalityValid = false
                    municipalityErrorMessage = error.rawValue
                } else if field == division {
                    isDivisionValid = false
                    divisionErrorMessage = error.rawValue
                } else if field == zone {
                    isZoneValid = false
                    zoneErrorMessage = error.rawValue
                } else if field == island {
                    isIslandValid = false
                    islandErrorMessage = error.rawValue
                } else if field == country {
                    isCountryValid = false
                    countryErrorMessage = error.rawValue
                }
                else if field == entity {
                    isEntityValid = false
                    entityErrorMessage = error.rawValue
                }
            case .email:
                isEmailValid = false
                emailErrorMessage = error.rawValue
            case .password:
                isPasswordValid = false
                passwordErrorMessage = error.rawValue
            default:
                break
            }
        } else {
            switch type {
            case .userName:
                isUserNameValid = true
                userNameErrorMessage = ""
            case .name:
                if field == name {
                    isNameValid = true
                    nameErrorMessage = ""
                } else if field == islandName {
                    isIslandNameValid = true
                    islandNameErrorMessage = ""
                } else if field == street {
                    isStreetValid = true
                    streetErrorMessage = ""
                } else if field == city {
                    isCityValid = true
                    cityErrorMessage = ""
                } else if field == state {
                    isStateValid = true
                    stateErrorMessage = ""
                } else if field == postalCode {
                    isPostalCodeValid = true
                    postalCodeErrorMessage = ""
                } else if field == gymWebsite {
                    isGymWebsiteValid = true
                    gymWebsiteErrorMessage = ""
                } else if field == gymWebsiteURL {
                    isGymWebsiteURLValid = true
                    gymWebsiteURLErrorMessage = ""
                } else if field == province {
                    isProvinceValid = true
                    provinceErrorMessage = ""
                } else if field == region {
                    isRegionValid = true
                    regionErrorMessage = ""
                } else if field == district {
                    isDistrictValid = true
                    districtErrorMessage = ""
                } else if field == department {
                    isDepartmentValid = true
                    departmentErrorMessage = ""
                } else if field == governorate {
                    isGovernorateValid = true
                    governorateErrorMessage = ""
                } else if field == emirate {
                    isEmirateValid = true
                    emirateErrorMessage = ""
                } else if field == county {
                    isCountyValid = true
                    countyErrorMessage = ""
                } else if field == neighborhood {
                    isNeighborhoodValid = true
                    neighborhoodErrorMessage = ""
                } else if field == complement {
                    isComplementValid = true
                    complementErrorMessage = ""
                } else if field == block {
                    isBlockValid = true
                    blockErrorMessage = ""
                } else if field == apartment {
                    isApartmentValid = true
                    apartmentErrorMessage = ""
                } else if field == additionalInfo {
                    isAdditionalInfoValid = true
                    additionalInfoErrorMessage = ""
                } else if field == multilineAddress {
                    isMultilineAddressValid = true
                    multilineAddressErrorMessage = ""
                } else if field == parish {
                    isParishValid = true
                    parishErrorMessage = ""
                } else if field == municipality {
                    isMunicipalityValid = true
                    municipalityErrorMessage = ""
                } else if field == division {
                    isDivisionValid = true
                    divisionErrorMessage = ""
                } else if field == zone {
                    isZoneValid = true
                    zoneErrorMessage = ""
                } else if field == island {
                    isIslandValid = true
                    islandErrorMessage = ""
                } else if field == country {
                    isCountryValid = true
                    countryErrorMessage = ""
                }
                else if field == entity {
                    isEntityValid = true
                    entityErrorMessage = ""
                }
            case .email:
                isEmailValid = true
                emailErrorMessage = ""
            case .password:
                isPasswordValid = true
                passwordErrorMessage = ""
            default:
                break
            }
        }
    }

    mutating func validateConfirmPassword() {
        isConfirmPasswordValid = confirmPassword == password
        confirmPasswordErrorMessage = isConfirmPasswordValid ? "" : "Passwords do not match."
    }
}

enum ValidationRule {
    case minLength(Int)
    case notEmpty
    case email
}
