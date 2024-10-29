//
//  AdminLoginView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/28/24.
//

import Foundation
import SwiftUI

struct AdminLoginView: View {
    @Binding var isPresented: Bool            // Binding to dismiss the view
    @Binding var navigateToAdminMenu: Bool    // Binding to trigger navigation to AdminMenu
    @EnvironmentObject var authenticationState: AuthenticationState

    @State private var adminUsername: String = ""
    @State private var adminPassword: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack {
            Text("Admin Login")
                .font(.title)
                .padding()

            TextField("Username", text: $adminUsername)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            SecureField("Password", text: $adminPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Login") {
                Task {
                    await adminLogin() // Call to the login function
                }
            }
            .padding()
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Admin Login"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    // Dismiss the login view if access is granted
                    if alertMessage == "Access Granted" {
                        isPresented = false // Dismiss only if access is granted
                    }
                }
            )
        }
    }

    private func adminLogin() async {
        let isValid = await AuthenticationHelper.verifyAdminCredentials(username: adminUsername, password: adminPassword)

        if isValid {
            print("Access granted. Navigating to AdminMenu.")
            alertMessage = "Access Granted"
            authenticationState.isAuthenticated = true  // Ensure authentication state is updated
            navigateToAdminMenu = true
            print("navigateToAdminMenu: \(navigateToAdminMenu)")
            print("authenticationState.isAuthenticated: \(authenticationState.isAuthenticated)")
            isPresented = false // Dismiss the login view if necessary
        } else {
            print("Invalid credentials.")
            alertMessage = "Invalid credentials."
        }
        
        showAlert = true
    }
}
