//
//  FormFieldViews.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import SwiftUI

// REUSABLE FIELD VIEWS
struct UserNameField: View {
    @Binding var userName: String  // Updated here
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    var validateUserName: (String) -> String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Username")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your username", text: $userName)  // Updated here
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: userName) { newValue in  // Updated here
                    let validationMessage = validateUserName(newValue)
                    isValid = validationMessage == nil
                    errorMessage = validationMessage ?? ""
                }
            if !isValid {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}

struct NameField: View {
    @Binding var name: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    var validateName: (String) -> String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Name")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: name) { newValue in
                    let validationMessage = validateName(newValue)
                    isValid = validationMessage == nil
                    errorMessage = validationMessage ?? ""
                }
            if !isValid {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                Text("Name can contain any characters.")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }
}

struct EmailField: View {
    @Binding var email: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    var validateEmail: (String) -> String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Email")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: email) { newValue in
                    let validationMessage = validateEmail(newValue)
                    isValid = validationMessage == nil
                    errorMessage = validationMessage ?? ""
                }
            if !isValid {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}

struct PasswordField: View {
    @Binding var password: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    @Binding var bypassValidation: Bool
    var validatePassword: (String) -> (Bool, String?)

    func updatePasswordValidation(_ password: String) {
        if !bypassValidation {
            let result = validatePassword(password)
            isValid = result.0
            errorMessage = result.1 ?? ""
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Password")
                Text("*").foregroundColor(.red)
            }
            SecureField("Enter your password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: password) { newValue in
                    updatePasswordValidation(newValue)
                }
            if !isValid && !bypassValidation {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            } else if !bypassValidation {
                Text("Password must be at least 8 characters, contain uppercase, lowercase, and digits.")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            HStack {
                Toggle("Bypass password validation", isOn: $bypassValidation)
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: bypassValidation) { newValue in
                        updatePasswordValidation(password)
                    }
                Text("Use at your own risk")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }
}

struct ConfirmPasswordField: View {
    @Binding var confirmPassword: String
    @Binding var isValid: Bool
    @Binding var password: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Confirm Password")
                Text("*").foregroundColor(.red)
            }
            SecureField("Confirm your password", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: confirmPassword) { newValue in
                    isValid = newValue == password
                }
            if !isValid {
                Text("Passwords do not match.")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            if !password.isEmpty && !confirmPassword.isEmpty {
                if password == confirmPassword {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.large)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.systemGreen))
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.systemRed))
                }
            }
        }
    }
}
