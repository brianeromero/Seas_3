//
//  ValidationUtility.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation

// MARK: - Validation Error

enum ValidationError: String, Error, Equatable {
    case none = ""
    case invalidEmail = "Invalid email format."
    case invalidUsername = "Username must be at least 7 characters long and can include letters, numbers, spaces, and underscores."
    case invalidPassword = "Password should be at least 8 characters long."
    case tooShort = "Password is too short."
    case missingUppercase = "Password must contain at least one uppercase letter."
    case invalidIslandName = "Gym name is required123."
    case invalidLocation = "Street, city, state, and postal code are required."
    case invalidURL = "Invalid URL format."
    case usernameTaken = "Username already exists."
    case emptyName = "Name cannot be empty."
    case missingLowercase = "Password must contain at least one lowercase letter."
    case missingNumber = "Password must contain at least one number."
    case missingSpecialCharacter = "Password must contain at least one special character."
}

// MARK: - Validation Type

enum ValidationType: String {
    case userName
    case email
    case name
    case password
    case islandName
    case url
    case location
}

// MARK: - Validation Utility

class ValidationUtility {
    // MARK: - Regex Constants
    
    private static let emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    private static let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
    private static let urlRegex = "^(https?:\\/\\/)?([\\da-z\\.-]+)\\.([a-z\\.]{2,6})([\\/\\w \\.-]*)*\\/?$"
    private static let userNameRegex = #"^[a-zA-Z0-9_](?:[a-zA-Z0-9_ ]{5,}[a-zA-Z0-9_])$"#
    private static let zipRegex = "^[0-9]{5}(?:-[0-9]{4})?$"
    private static let postalCode = "^[0-9]{5}(?:-[0-9]{4})?$"
    internal static let postalCodeRegexPatterns: [String: String] = [
        // Americas
        "US": "^\\d{5}(-\\d{4})?$", // United States (12345 or 12345-6789)
        "CA": "^([ABCEGHJKLMNPRSTVXY]\\d[ABCEGHJKLMNPRSTVWXYZ] {0,1}\\d[ABCEGHJKLMNPRSTVWXYZ]\\d)$", // Canada (A1A 1A1)
        "BR": "^\\d{8}$", // Brazil (12345678)
        "MX": "^\\d{5}$", // Mexico (12345)
        
        // Europe
        "GB": "^([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9]?[A-Za-z]))))\\s?[0-9][A-Za-z]{2})$", // United Kingdom (Postalcode)
        "FR": "^\\d{5}$", // France (12345)
        "DE": "^\\d{5}$", // Germany (12345)
        "ES": "^\\d{5}$", // Spain (12345)
        "IT": "^\\d{5}$", // Italy (12345)
        
        // Asia
        "CN": "^\\d{6}$", // China (123456)
        "JP": "^\\d{3}-\\d{4}$", // Japan (123-4567)
        "IN": "^\\d{6}$", // India (123456)
        "KR": "^\\d{5}-\\d{4}$", // South Korea (12345-6789)
        
        // Africa
        "EG": "^\\d{5}$", // Egypt (12345)
        "ZA": "^\\d{4}$", // South Africa (1234)
        "NG": "^\\d{6}$", // Nigeria (123456)
        
        // Oceania
        "AU": "^\\d{4}$", // Australia (1234)
        
        // Additional countries
        "AE": "^\\d{5}$", // United Arab Emirates (12345)
        "IL": "^\\d{5}$", // Israel (12345)
        "CL": "^\\d{7}$", // Chile (1234567)
        "CO": "^\\d{6}$", // Colombia (123456)
        "TR": "^\\d{5}$", // Turkey (12345)
        "TH": "^\\d{5}$", // Thailand (12345)
        "SA": "^\\d{5}$", // Saudi Arabia (12345)
        "PK": "^\\d{5}$", // Pakistan (12345)
        "VN": "^\\d{6}$", // Vietnam (123456)
        "PH": "^\\d{4}$", // Philippines (1234)
        "ID": "^\\d{5}$", // Indonesia (12345)
        "AR": "^\\d{8}$", // Argentina (12345678)
        "RU": "^\\d{6}$" // Russia (123456)
    ]
    
    static func validatePostalCode(_ postalCode: String, for country: String) -> ValidationError? {
        guard let regexPattern = postalCodeRegexPatterns[country] else {
            return .invalidLocation
        }
        
        let postalCodePredicate = NSPredicate(format: "SELF MATCHES %@", regexPattern)
        if !postalCodePredicate.evaluate(with: postalCode) {
            return .invalidLocation
        }
        return nil
    }
    
    // MARK: Username Existence Check
    
    static func userNameIsTaken(_ userName: String) -> Bool {
        // Logic to check if username is taken in your database or storage system
        // Replace with actual implementation
        return false
    }
    
    // MARK: - Validation Functions
    
    static func validateEmail(_ email: String) -> ValidationError? {
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        if !emailPredicate.evaluate(with: email) {
            return .invalidEmail
        }
        return nil
    }
    
    static func validateUserName(_ userName: String) -> ValidationError? {
        if userName.count < 7 || userName.range(of: userNameRegex, options: .regularExpression) == nil {
            return .invalidUsername
        } else if userNameIsTaken(userName) {
            return .usernameTaken
        }
        return nil
    }
    
    static func validateName(_ name: String) -> ValidationError? {
        if name.isEmpty {
            return .emptyName
        }
        return nil
    }
    
    static func isValidPassword(_ password: String) -> ValidationError? {
        if password.count < 8 {
            return .tooShort
        }
        if !password.contains(where: { $0.isUppercase }) {
            return .missingUppercase
        }
        if !password.contains(where: { $0.isLowercase }) {
            return .missingLowercase
        }
        if !password.contains(where: { $0.isNumber }) {
            return .missingNumber
        }
        if !password.contains(where: { !$0.isLetter && !$0.isNumber }) {
            return .missingSpecialCharacter
        }
        return nil
    }
    
    static func validateIslandName(_ name: String) -> ValidationError? {
        if name.isEmpty {
            return .invalidIslandName
        }
        return nil
    }
    
    static func validateURL(_ urlString: String) -> ValidationError? {
        let urlPredicate = NSPredicate(format: "SELF MATCHES %@", urlRegex)
        if !urlPredicate.evaluate(with: urlString) {
            return .invalidURL
        }
        return nil
    }
    
    
    static func validateLocation(_ street: String, _ city: String, _ state: String, _ postalCode: String, for country: String) -> ValidationError? {
        if [street, city, state, postalCode].contains(where: \.isEmpty) {
            return .invalidLocation
        }
        
        if let error = validatePostalCode(postalCode, for: country) {
            return error
        }
        
        return nil
    }
    
    static func validateField(_ value: String, type: ValidationType) -> ValidationError? {
        switch type {
        case .email:
            return validateEmail(value)
        case .userName:
            return validateUserName(value)
        case .name:
            return validateName(value)
        case .password:
            return isValidPassword(value)
        case .islandName:
            return validateIslandName(value)
        case .url:
            return validateURL(value)
        case .location:
            // Location validation requires multiple fields, so we can't validate it here
            return nil
        }
    }
    
    static func validateIslandForm(
        islandName: String,
        street: String,
        city: String,
        state: String,
        postalCode: String,
        neighborhood: String? = nil,  // For Brazil
        complement: String? = nil,    // For Brazil
        province: String? = nil,      // For Canada and China
        region: String? = nil,        // For Russia
        district: String? = nil,      // For Israel
        department: String? = nil,    // For Colombia
        governorate: String? = nil,   // For Egypt
        emirate: String? = nil,       // For United Arab Emirates
        apartment: String? = nil,     // For Russia
        additionalInfo: String? = nil,// For Saudi Arabia
        selectedCountry: Country?,
        gymWebsite: String,
        latitude: Double? = nil,      // Add latitude as optional
        longitude: Double? = nil,     // Add longitude as optional
        country: String = "",        // Add country as a String parameter
        county: String = "",         // Add county as a String parameter
        requiredAddressFields: [AddressFieldType] = [], // Add requiredAddressFields
        gymWebsiteURL: URL? = nil     // Add gymWebsiteURL as optional
    ) -> (isValid: Bool, errorMessage: String) {

        // Validate island name
        if islandName.isEmpty {
            return (false, "Island name is required.")
        }

        // Validate country selection
        guard let selectedCountry = selectedCountry else {
            return (false, "Please select a country.")
        }

        // Get required address fields for the selected country
        do {
            let requiredFields = try getAddressFields(for: selectedCountry.cca2)

            // Function to dynamically validate address fields
            func validateField(_ field: String?, fieldName: String) -> (isValid: Bool, errorMessage: String)? {
                if field?.isEmpty ?? true {
                    return (false, "\(fieldName) is required.")
                }
                return nil
            }

            // Validate address fields dynamically using the required fields list
            let islandDetails = IslandDetails(
                islandName: islandName,
                street: street,
                city: city,
                state: state,
                postalCode: postalCode,
                latitude: latitude,
                longitude: longitude,
                selectedCountry: selectedCountry,
                country: country,
                county: county,
                additionalInfo: additionalInfo ?? "",
                requiredAddressFields: requiredAddressFields,
                gymWebsite: gymWebsite,
                gymWebsiteURL: gymWebsiteURL
            )

            // Iterate through required fields and check their corresponding island details
            for field in requiredFields {
                // Dynamically check each required address field based on its keyPath
                let keyPath = AddressField(rawValue: field.rawValue)?.keyPath ?? \.street

                // Safely unwrap and trim the string value
                let value = islandDetails[keyPath: keyPath].trimmingCharacters(in: .whitespaces)

                // Check if the value is empty
                if value.isEmpty {
                    return (false, "\(field.rawValue) is required.")
                }
            }

            // Country-specific address validations
            if let result = validateField(street, fieldName: "Street"), requiredFields.contains(.street) { return result }
            if let result = validateField(city, fieldName: "City"), requiredFields.contains(.city) { return result }
            if let result = validateField(state, fieldName: "State"), requiredFields.contains(.state) { return result }
            if let result = validateField(postalCode, fieldName: "Postal code"), requiredFields.contains(.postalCode) { return result }

            // Country-specific validations for optional fields
            if let result = validateField(province, fieldName: "Province"), requiredFields.contains(.province) { return result }
            if let result = validateField(region, fieldName: "Region"), requiredFields.contains(.region) { return result }
            if let result = validateField(district, fieldName: "District"), requiredFields.contains(.district) { return result }
            if let result = validateField(department, fieldName: "Department"), requiredFields.contains(.department) { return result }
            if let result = validateField(governorate, fieldName: "Governorate"), requiredFields.contains(.governorate) { return result }
            if let result = validateField(emirate, fieldName: "Emirate"), requiredFields.contains(.emirate) { return result }
            if let result = validateField(apartment, fieldName: "Apartment"), requiredFields.contains(.apartment) { return result }
            if let result = validateField(additionalInfo, fieldName: "Additional info"), requiredFields.contains(.additionalInfo) { return result }
            if let result = validateField(neighborhood, fieldName: "Neighborhood"), requiredFields.contains(.neighborhood) { return result }
            if let result = validateField(complement, fieldName: "Complement"), requiredFields.contains(.complement) { return result }

        } catch {
            // Handle the case where getAddressFields throws an error
            return (false, "Error getting address fields for country code \(selectedCountry.cca2)")
        }

        // Validate website URL if provided
        if !gymWebsite.isEmpty {
            if validateURL(gymWebsite) != nil {
                return (false, "Invalid website URL.")
            }
        }

        // All validations passed
        return (true, "")
    }
}
