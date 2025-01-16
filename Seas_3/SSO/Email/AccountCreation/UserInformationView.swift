//
//  UserInformationView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import SwiftUI

struct UserInformationView: View {
    @Binding var formState: FormState
    @State private var fieldName: String = ""
    @State private var bypassPasswordValidation: Bool = false

    
    var body: some View {
        Section(content: {
            createField(
                title: "Username",
                binding: $formState.userName,
                validationType: .userName
            )
            
            createField(
                title: "Name",
                binding: $formState.name,
                validationType: .name
            )
            
            createField(
                title: "Email",
                binding: $formState.email,
                validationType: .email
            )
        }, header: {
            Text("User Information").fontWeight(.bold)
                .padding(.horizontal, 20)
        })
    }
    
    // MARK: - Private Functions

    private func createField(
        title: String,
        binding: Binding<String>,
        validationType: ValidationType
    ) -> some View {
        precondition(!title.isEmpty, "Title cannot be empty")

        return VStack {
            switch validationType {
            case .userName:
                UserNameField(
                    userName: binding,
                    isValid: $formState.isUserNameValid,
                    errorMessage: $formState.userNameErrorMessage,
                    validateField: { value in
                        if let error = ValidationUtility.validateUserName(value) {
                            return (false, error.rawValue)
                        } else {
                            return (true, "")
                        }
                    }
                )

            case .email:
                EmailField(
                    email: binding,
                    isValid: $formState.isEmailValid,
                    errorMessage: $formState.emailErrorMessage,
                    validateField: { value in
                        if let error = ValidationUtility.validateEmail(value) {
                            return (false, error.rawValue)
                        } else {
                            return (true, "")
                        }
                    }
                )
            case .name:
                NameField(
                    name: binding,
                    isValid: $formState.isNameValid,
                    errorMessage: $formState.nameErrorMessage,
                    validateField: { value in
                        if let error = ValidationUtility.validateName(value) {
                            return (false, error.rawValue)
                        } else {
                            return (true, "")
                        }
                    }
                )
            default:
                EmptyView()
            }
        }
        .onChange(of: binding.wrappedValue) { newValue in
            formState.validateField(newValue, type: validationType)
        }
    }
    
    private func validateField(_ value: String, type: ValidationType) {
        if let error = ValidationUtility.validateField(value, type: type) {
            handleValidationError(error, for: type)
        } else {
            handleValidationSuccess(for: type)
        }
    }

    
    private func handleValidationError(_ error: ValidationError, for type: ValidationType) {
        let (isValid, errorMessage) = validationErrorHandling(type, error: error)
        updateFormState(type, isValid: isValid, errorMessage: errorMessage)
    }
    
    private func handleValidationSuccess(for type: ValidationType) {
        updateFormState(type, isValid: true, errorMessage: "")
    }
    
    private func validationErrorHandling(_ type: ValidationType, error: ValidationError) -> (Bool, String) {
        return (false, error.rawValue)
    }
    
    private func updateFormState(_ type: ValidationType, isValid: Bool, errorMessage: String) {
        switch type {
        case .userName:
            formState.isUserNameValid = isValid
            formState.userNameErrorMessage = errorMessage
        case .name:
            formState.isNameValid = isValid
            formState.nameErrorMessage = errorMessage
        case .email:
            formState.isEmailValid = isValid
            formState.emailErrorMessage = errorMessage
        default:
            print("Unexpected ValidationType: \(type)")
        }
    }
}
