//  AccountAuthView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import CoreData
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAppCheck
import CryptoSwift
import Combine


// Define a custom error enum
enum AccountAuthViewError: Error, LocalizedError {
    case emailMissing
    case passwordMismatch
    case invalidPassword
    case coreDataError
    case unknownError
    case userAlreadyExists

    
    var errorDescription: String? {
        switch self {
        case .emailMissing:
            return "Email is missing."
        case .passwordMismatch:
            return "Passwords do not match."
        case .invalidPassword:
            return "Invalid password."
        case .coreDataError:
            return "Error saving user to Core Data."
        case .unknownError:
            return "An unknown error occurred."
        case .userAlreadyExists:
            return "User already exists. Please log in or request password reset."

        }
    }
}

struct AccountAuthView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Binding var isUserProfileActive: Bool
    @State private var formState: FormState = FormState()
    @ObservedObject private var authViewModel = AuthViewModel.shared // Add this line
    @State private var showVerificationAlert = false
    @State private var errorMessage = ""
    @Environment(\.managedObjectContext) private var viewContext
    let persistenceController = PersistenceController.shared
    @State private var isLoginSelected = false
    let emailManager: UnifiedEmailManager
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @State private var selectedTabIndex = 0
    @State private var isSelected: LoginViewSelection = .login
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @Binding var navigateToAdminMenu: Bool
    @State private var isLoggedIn: Bool = false


    init(islandViewModel: PirateIslandViewModel,
         isUserProfileActive: Binding<Bool>,
         navigateToAdminMenu: Binding<Bool> = .constant(false),
         emailManager: UnifiedEmailManager = .shared) {
        self._islandViewModel = ObservedObject(wrappedValue: islandViewModel)
        self._isUserProfileActive = isUserProfileActive
        self._navigateToAdminMenu = navigateToAdminMenu
        self.emailManager = emailManager
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isSelected == .login {
                    VStack(spacing: 20) {
                        LoginForm(
                            usernameOrEmail: $authViewModel.usernameOrEmail,
                            password: $authViewModel.password,
                            isSignInEnabled: $authViewModel.isSignInEnabled,
                            errorMessage: $errorMessage,
                            islandViewModel: islandViewModel,
                            showMainContent: .constant(false),
                            isLoggedIn: $isLoggedIn,
                            navigateToAdminMenu: $navigateToAdminMenu
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        
                        Spacer()
                    }
                } else if isSelected == .createAccount {
                    CreateAccountView(
                        islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                        isUserProfileActive: $isUserProfileActive,
                        persistenceController: PersistenceController.shared,
                        selectedTabIndex: $selectedTabIndex,
                        emailManager: UnifiedEmailManager.shared
                    )
                }
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Authentication Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}
