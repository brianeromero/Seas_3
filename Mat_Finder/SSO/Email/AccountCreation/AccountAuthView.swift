//  AccountAuthView.swift
//  Mat_Finder
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
    @State private var isSelected: LoginViewSelection = .login
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @Binding var navigateToAdminMenu: Bool
    @State private var isLoggedIn: Bool = false
    @State private var navigationPath = NavigationPath()

    @State private var currentAlertType: AccountAlertType? = nil


    init(islandViewModel: PirateIslandViewModel,
         isUserProfileActive: Binding<Bool>,
         navigateToAdminMenu: Binding<Bool> = .constant(false),
         emailManager: UnifiedEmailManager) {
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
                        islandViewModel: islandViewModel,
                        isUserProfileActive: .constant(false),
                        selectedTabIndex: $isSelected,  // ✅ pass existing state
                        navigationPath: $navigationPath,
                        persistenceController: PersistenceController.shared,
                        emailManager: UnifiedEmailManager.shared,
                        showAlert: $showAlert,
                        alertTitle: $alertTitle,       // ✅ pass the binding here
                        alertMessage: $alertMessage,
                        currentAlertType: $currentAlertType      // <-- add this
                        
                    )

                }
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}
