//
//  ValidationUtility.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation


enum ValidationType {
    case username, email, name, password
}


class ValidationUtility {
    
    // Email validation
    static func validateEmail(_ email: String) -> String? {
        print("Validating email: \(email)")
        let emailPredicate = NSPredicate(format: "SELF MATCHES[c] %@",
                                         "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
        if !emailPredicate.evaluate(with: email) {
            print("Email validation failed")
            return "Invalid email format. Please use 'example@example.com'."
        }
        print("Email validation succeeded")
        return nil
    }
    
    // Username validation
    static func validateUsername(_ username: String) -> String? {
        if username.count < 7 || !username.isAlphanumeric {
            return "Username should be at least 7 characters long and contain only alphanumeric characters."
        } else if usernameIsTaken(username) {
            return "Username already exists."
        }
        return nil
    }
    
    // Name validation (currently no validation)
    static func validateName(_ name: String) -> String? {
        if name.isEmpty {
            return "Name cannot be empty."
        }
        return nil
    }
    
    // Password validation
    static func isValidPassword(_ password: String) -> (Bool, String?) {
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        
        if !passwordPredicate.evaluate(with: password) {
            let feedback: String
            if password.count < 8 {
                feedback = "Password should be at least 8 characters long."
            } else if !password.contains(where: \.isLowercase) {
                feedback = "Password should contain at least one lowercase letter."
            } else if !password.contains(where: \.isUppercase) {
                feedback = "Password should contain at least one uppercase letter."
            } else if !password.contains(where: \.isNumber) {
                feedback = "Password should contain at least one number."
            } else {
                feedback = "Invalid password"
            }
            return (false, feedback)
        }
        return (true, nil)
    }
    
    // Check if username is taken (replace with actual implementation)
    static func usernameIsTaken(_ username: String) -> Bool {
        // Logic to check if username is taken in your database or storage system
        // Replace with actual implementation
        // For example:
        // return UserDefaults.standard.bool(forKey: "usernameTaken\(username)")
        // or
        // return database usernames.contains(username)
        return false
    }
    
    // Generic field validation
    static func validateField(_ field: String, type: ValidationType) -> String? {
        switch type {
        case .username:
            return validateUsername(field)
        case .email:
            return validateEmail(field)
        case .name:
            return validateName(field)
        case .password:
            let (isValid, feedback) = isValidPassword(field)
            return isValid ? nil : feedback
        }
    }
}
