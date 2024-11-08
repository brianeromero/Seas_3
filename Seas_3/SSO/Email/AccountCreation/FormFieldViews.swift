//
//  FormFieldViews.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import SwiftUI

// MARK: - Reusable Field Views

struct UserNameField: View {
    @Binding var userName: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    var validateField: (String) -> String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Username")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your username", text: $userName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: userName) { newValue in validateField(newValue) }
            validationMessage
        }
    }

    var validationMessage: some View {
        if !isValid {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
        } else {
            Text("")
        }
    }

    private func validateField(_ userName: String) {
        let validationMessage = ValidationUtility.validateField(userName, type: .userName)
        isValid = validationMessage == nil
        errorMessage = validationMessage?.rawValue ?? ""
    }
}

struct NameField: View {
    @Binding var name: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    var validateField: (String) -> String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Name")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: name) { newValue in validateField(newValue) }
            validationMessage
            hintMessage
        }
    }

    var validationMessage: some View {
        if !isValid {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
        } else {
            Text("")
        }
    }

    var hintMessage: some View {
        if isValid {
            Text("Name can contain any characters.")
                .foregroundColor(.gray)
                .font(.caption)
        } else {
            Text("")
        }
    }

    private func validateField(_ name: String) {
        let validationMessage = ValidationUtility.validateField(name, type: .name)
        isValid = validationMessage == nil
        errorMessage = validationMessage?.rawValue ?? ""
    }
}

struct EmailField: View {
    @Binding var email: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    var validateField: (String) -> String?

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Email")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: email) { newValue in validateField(newValue) }
            validationMessage
        }
    }

    var validationMessage: some View {
        if !isValid {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
        } else {
            Text("")
        }
    }

    private func validateField(_ email: String) {
        let validationMessage = ValidationUtility.validateField(email, type: .email)
        isValid = validationMessage == nil
        errorMessage = validationMessage?.rawValue ?? ""
    }
}

struct PasswordField: View {
    @Binding var password: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    @Binding var bypassValidation: Bool
    var validateField: (String) -> String?
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Password")
                Text("*").foregroundColor(.red)
            }
            SecureField("Enter your password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: password) { newValue in updatePasswordValidation(newValue) }
            validationMessage
            hintMessage
            Toggle("Bypass password validation", isOn: $bypassValidation)
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: bypassValidation) { _ in updatePasswordValidation(password) }
            Text("Use at your own risk")
                .foregroundColor(.gray)
                .font(.caption)
        }
    }
    
    var validationMessage: some View {
        if !isValid {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
        } else {
            Text("")
        }
    }
    
    var hintMessage: some View {
        if !bypassValidation {
            Text("Password must be at least 8 characters, contain uppercase, lowercase, and digits.")
                .foregroundColor(.gray)
                .font(.caption)
        } else {
            Text("")
        }
    }
    
    private func updatePasswordValidation(_ password: String) {
        if !bypassValidation {
            let validationMessage = ValidationUtility.validateField(password, type: .password)
            isValid = validationMessage == nil
            errorMessage = validationMessage?.rawValue ?? ""
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
            ValidationMessage(isValid: isValid, password: password, confirmPassword: confirmPassword)
        }
    }
}

struct GymInformationSection: View {
    @Binding var islandName: String
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    @Binding var selectedProtocol: String
    @ObservedObject var islandViewModel: PirateIslandViewModel

    var body: some View {
        Section(header: HStack {
            Text("Gym Information")
                .fontWeight(.bold)
            Text("(Optional)")
                .foregroundColor(.gray)
                .opacity(0.7)
        }) {
            IslandFormSections(
                viewModel: islandViewModel,
                islandName: $islandName,
                street: $street,
                city: $city,
                state: $state,
                zip: $zip,
                gymWebsite: $gymWebsite,
                gymWebsiteURL: $gymWebsiteURL,
                selectedProtocol: $selectedProtocol,
                showAlert: .constant(false),
                alertMessage: .constant("")
            )
        }
    }
}



struct IslandNameField: View {
    @Binding var islandName: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Island Name", text: $islandName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if !isValid {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }
}

struct LocationField: View {
    @Binding var location: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Location", text: $location)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if !isValid {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }
}

struct URLField: View {
    @Binding var url: String
    @Binding var isValid: Bool
    @Binding var errorMessage: String
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("URL", text: $url)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            if !isValid {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }
}


struct BeltSection: View {
    @Binding var belt: String
    let beltOptions = ["White", "Blue", "Purple", "Brown", "Black"]

    var body: some View {
        Section(header: HStack {
            Text("Belt")
            Text("(Optional)")
                .foregroundColor(.gray)
                .opacity(0.7)
        }) {
            Menu {
                ForEach(beltOptions, id: \.self) { belt in
                    Button(action: {
                        self.belt = belt
                    }) {
                        Text(belt)
                    }
                }
            } label: {
                HStack {
                    Text(belt.isEmpty ? "Select a belt" : belt)
                        .foregroundColor(belt.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct ValidationMessage: View {
    let isValid: Bool
    let password: String
    let confirmPassword: String

    var body: some View {
        VStack {
            if !isValid {
                Text("Passwords do not match.")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            if !password.isEmpty && !confirmPassword.isEmpty {
                Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .imageScale(.large)
                    .fontWeight(.bold)
                    .foregroundColor(password == confirmPassword ? Color(.systemGreen) : Color(.systemRed))
            }
        }
    }
}
