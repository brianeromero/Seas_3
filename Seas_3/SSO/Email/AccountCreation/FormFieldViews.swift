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
    var validateField: (String) -> (Bool, String)
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Username")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your username", text: $userName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: userName) { newValue in
                    let (newIsValid, newErrorMessage) = validateField(newValue)
                    self.isValid = newIsValid
                    self.errorMessage = newErrorMessage
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
    var validateField: (String) -> (Bool, String)
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Name")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: name) { newValue in
                    let (newIsValid, newErrorMessage) = validateField(newValue)
                    self.isValid = newIsValid
                    self.errorMessage = newErrorMessage
                }
            
            if !isValid {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if isValid {
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
    var validateField: (String) -> (Bool, String)
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Email")
                Text("*").foregroundColor(.red)
            }
            TextField("Enter your email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: email) { newValue in
                    let (newIsValid, newErrorMessage) = validateField(newValue)
                    self.isValid = newIsValid
                    self.errorMessage = newErrorMessage
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
    var validateField: (String) -> (Bool, String)
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Password")
                Text("*").foregroundColor(.red)
            }
            SecureField("Enter your password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: password) { newValue in
                    let (newIsValid, newErrorMessage) = validateField(newValue)
                    self.isValid = newIsValid
                    self.errorMessage = newErrorMessage
                }
            
            if !isValid {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if !bypassValidation {
                Text("Password must be at least 8 characters, contain uppercase, lowercase, and digits.")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            Toggle("Bypass password validation", isOn: $bypassValidation)
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: bypassValidation) { _ in
                    let (newIsValid, newErrorMessage) = validateField(password)
                    self.isValid = newIsValid
                    self.errorMessage = newErrorMessage
                }
            Text("Use at your own risk")
                .foregroundColor(.gray)
                .font(.caption)
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
    @Binding var postalCode: String
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    @Binding var selectedProtocol: String
    @Binding var province: String
    @Binding var selectedCountry: Country?
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel // Add this
    
    // Define islandDetails, assuming it's a structure with necessary fields
    @State private var islandDetails: IslandDetails // Example type, replace with your actual model
    @State private var neighborhood: String = ""
    @State private var complement: String = ""
    @State private var apartment: String = ""
    @State private var region: String = ""
    @State private var county: String = ""
    @State private var governorate: String = ""
    @State private var additionalInfo: String = ""
    
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
                postalCode: $postalCode,
                province: $province,
                neighborhood: $neighborhood,
                complement: $complement,
                apartment: $apartment,
                region: $region,
                county: $county,
                governorate: $governorate,
                additionalInfo: $additionalInfo,
                gymWebsite: $gymWebsite,
                gymWebsiteURL: $gymWebsiteURL,
                showAlert: .constant(false),
                alertMessage: .constant(""),
                selectedCountry: $selectedCountry,
                islandDetails: $islandDetails,
                profileViewModel: profileViewModel
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
