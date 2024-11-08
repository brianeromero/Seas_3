//
//  ValidationUtility.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

//  ValidationUtility.swift

import Foundation
// MARK: - Validation Error

enum ValidationError: String, Error, Equatable {
    case none = ""
    case invalidEmail = "Invalid email format."
    case invalidUsername = "Username should be at least 7 characters long."
    case invalidPassword = "Password should be at least 8 characters long."
    case tooShort = "Password is too short."
    case missingUppercase = "Password must contain at least one uppercase letter."
    case invalidIslandName = "Island name is required."
    case invalidLocation = "Street, city, state, and zip are required."
    case invalidURL = "Invalid URL format."
    case usernameTaken = "Username already exists."
    case emptyName = "Name cannot be empty."
}

// MARK: - Validation Type

enum ValidationType {
    case userName
    case email
    case name
    case password
}

// MARK: - Validation Utility

class ValidationUtility {
    // MARK: - Regex Constants
    
    private static let emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    private static let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
    private static let urlRegex = "^(https?:\\/\\/)?([\\da-z\\.-]+)\\.([a-z\\.]{2,6})([\\/\\w \\.-]*)*\\/?$"
    private static let userNameRegex = "^[a-zA-Z0-9_]{7,}$"
    private static let zipRegex = "^[0-9]{5}(?:-[0-9]{4})?$"

    // MARK: Username Existence Check

    static func userNameIsTaken(_ userName: String) -> Bool {
        // Logic to check if username is taken in your database or storage system
        // Replace with actual implementation
        return false
    }
}

extension ValidationUtility {
    // Single Field Validations
    
    /// Validate email address.
    static func validateEmail(_ email: String) -> ValidationError? {
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@", emailRegex)
        if !emailPredicate.evaluate(with: email) {
            return .invalidEmail
        }
        return nil
    }
    
    /// Validate username.
    static func validateUserName(_ userName: String) -> ValidationError? {
        if userName.count < 7 || userName.range(of: userNameRegex, options: .regularExpression) == nil {
            return .invalidUsername
        } else if userNameIsTaken(userName) {
            return .usernameTaken
        }
        return nil
    }
    
    /// Validate name.
    static func validateName(_ name: String) -> ValidationError? {
        if name.isEmpty {
            return .emptyName
        }
        return nil
    }
    
    /// Validate password.
    static func isValidPassword(_ password: String) -> ValidationError? {
        if password.count < 8 {
            return .tooShort
        }
        if !password.contains(where: { $0.isUppercase }) {
            return .missingUppercase
        }
        return nil
    }
    
    /// Validate island name.
    static func validateIslandName(_ name: String) -> ValidationError? {
        if name.isEmpty {
            return .invalidIslandName
        }
        return nil
    }
    
    /// Validate URL.
    static func validateURL(_ urlString: String) -> ValidationError? {
        let urlPredicate = NSPredicate(format: "SELF MATCHES %@", urlRegex)
        if !urlPredicate.evaluate(with: urlString) {
            return .invalidURL
        }
        return nil
    }
    
    /// Validate location.
    static func validateLocation(_ street: String, _ city: String, _ state: String, _ zip: String) -> ValidationError? {
        if [street, city, state, zip].contains(where: \.isEmpty) {
            return .invalidLocation
        }
        let zipPredicate = NSPredicate(format: "SELF MATCHES %@", zipRegex)
        if !zipPredicate.evaluate(with: zip) {
            return .invalidLocation
        }
        return nil
    }
}

extension ValidationUtility {
    // Ensure ValidationError is defined appropriately
    static func validateField(_ field: String, type: ValidationType) -> ValidationError? {
        switch type {
        case .userName:
            return validateUserName(field) // Ensure these methods return ValidationError?
        case .email:
            return validateEmail(field)
        case .name:
            return validateName(field)
        case .password:
            return isValidPassword(field)
        }
    }
    
    /// Validate multiple fields.
    static func validateFields(_ islandName: String, _ street: String, _ city: String, _ state: String, _ zip: String, _ gymWebsite: String) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if let error = validateIslandName(islandName) {
            errors.append(error)
        }
        
        if let error = validateLocation(street, city, state, zip) {
            errors.append(error)
        }
        
        if !gymWebsite.isEmpty, let error = validateURL(gymWebsite) {
            errors.append(error)
        }
        
        return errors
    }
}
