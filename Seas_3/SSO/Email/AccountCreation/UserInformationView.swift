//
//  UserInformationView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import SwiftUI

struct UserInformationView: View {
    @Binding var formState: FormState

    var body: some View {
        Section(header: Text("User Information").fontWeight(.bold)) {
            UserNameField(
                username: $formState.username,
                isValid: $formState.isUsernameValid,
                errorMessage: $formState.usernameErrorMessage,
                validateUsername: ValidationUtility.validateUsername
            )
            .onChange(of: formState.username) { newValue in
                formState.isUsernameValid = ValidationUtility.validateUsername(newValue) == nil
                formState.usernameErrorMessage = ValidationUtility.validateUsername(newValue) ?? ""
            }

            NameField(
                name: $formState.name,
                isValid: $formState.isNameValid,
                errorMessage: $formState.nameErrorMessage,
                validateName: ValidationUtility.validateName
            )
            .onChange(of: formState.name) { newValue in
                formState.isNameValid = ValidationUtility.validateName(newValue) == nil
                formState.nameErrorMessage = ValidationUtility.validateName(newValue) ?? ""
            }

            EmailField(
                email: $formState.email,
                isValid: $formState.isEmailValid,
                errorMessage: $formState.emailErrorMessage,
                validateEmail: ValidationUtility.validateEmail
            )
            .onChange(of: formState.email) { newValue in
                formState.isEmailValid = ValidationUtility.validateEmail(newValue) == nil
                formState.emailErrorMessage = ValidationUtility.validateEmail(newValue) ?? ""
            }
        }
    }
}
