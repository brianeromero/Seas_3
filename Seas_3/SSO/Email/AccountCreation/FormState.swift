//
//  FormState.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import SwiftUI

struct FormState {
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

    // Additional Information
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

    var postalCode: String = "" {
        didSet { validateField(postalCode, type: .name) }
    }
    var isPostalCodeValid: Bool = false
    var postalCodeErrorMessage: String = ""

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
            isPostalCodeValid
        ].allSatisfy { $0 } : true)

        // Gym website fields can be validated, but aren't required
        let gymWebsiteValidations = [
            isGymWebsiteValid,
            isGymWebsiteURLValid
        ].allSatisfy { $0 }

        // Combine all validations, excluding selectedProtocol
        return basicValidations && islandRelatedValidations && gymWebsiteValidations
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
