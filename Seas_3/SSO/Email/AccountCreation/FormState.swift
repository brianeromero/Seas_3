//
//  FormState.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation


struct FormState {
    var userName: String = ""
    var isUserNameValid: Bool = false
    var userNameErrorMessage: String = ""

    var name: String = ""
    var isNameValid: Bool = false
    var nameErrorMessage: String = ""

    var email: String = ""
    var isEmailValid: Bool = false
    var emailErrorMessage: String = ""

    var password: String = ""
    var isPasswordValid: Bool = false
    var passwordErrorMessage: String = ""

    var confirmPassword: String = ""
    var isConfirmPasswordValid: Bool = false
    var confirmPasswordErrorMessage: String = ""

    var isValid: Bool {
        return isUserNameValid && isNameValid && isEmailValid && isPasswordValid && isConfirmPasswordValid
    }
}
