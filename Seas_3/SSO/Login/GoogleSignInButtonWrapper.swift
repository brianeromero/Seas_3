//
//  GoogleSignInButtonWrapper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//

import Foundation
import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import CoreData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth


import os
import SwiftUI
import GoogleSignIn // Keep this import for GIDSignIn and its types
import os.log

struct GoogleSignInButtonWrapper: View {
    // 1. Remove @EnvironmentObject var authenticationState
    //    We will now interact with AuthViewModel.shared directly.
    // @EnvironmentObject var authenticationState: AuthenticationState // REMOVE THIS LINE
    
    var handleError: (String) -> Void // Still useful for UI error handling

    @State private var showError = false
    @State private var errorMessage = ""

    private let logger = os.Logger(subsystem: "com.seas3.app", category: "GoogleSignIn")

    // 2. Add @ObservedObject for AuthViewModel.shared
    //    We need @ObservedObject because AuthViewModel is an ObservableObject
    //    and we want this view to react to changes in its @Published properties
    //    (like errorMessage, though we'll propagate it manually here for the alert).
    @ObservedObject private var authViewModel = AuthViewModel.shared // ADD THIS LINE

    var body: some View {
        Button(action: handleSignIn) {
            HStack {
                Image(systemName: "g.circle")
                Text("Sign in with Google")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func handleSignIn() {
        logger.debug("Google sign-in started from button wrapper.")

        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
                let errMsg = "Unable to find root view controller for Google Sign-In."
                logger.error("\(errMsg, privacy: .public)") // Ensure proper logging format
                handleError(errMsg)
                return
        }

        Task {
            // 3. Call the signInWithGoogle method on the shared AuthViewModel instance
            await authViewModel.signInWithGoogle(presenting: rootVC)
            
            // 4. Check for error message from AuthViewModel and propagate it
            //    AuthViewModel.errorMessage is now the source of truth for errors.
            if let vmError = authViewModel.errorMessage, !vmError.isEmpty {
                errorMessage = vmError
                showError = true
                handleError(vmError) // Propagate to LoginForm if needed
                
                // Clear AuthViewModel's error message after displaying it
                // to prevent it from persisting for future interactions
                DispatchQueue.main.async {
                    self.authViewModel.errorMessage = ""
                }
            }
        }
    }
}
