//
//  AdminLoginView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/28/24.
//

import Foundation
import SwiftUI

struct AdminLoginView: View {
    @Binding var isPresented: Bool
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
                    await adminLogin()
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
                    if alertMessage == "Access Granted" {
                        isPresented = false
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
            authenticationState.adminLoginSucceeded()
            isPresented = false
        } else {
            print("Invalid credentials.")
            alertMessage = "Invalid credentials."
        }
        
        showAlert = true
    }
}
