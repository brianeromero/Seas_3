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

struct GoogleSignInButtonWrapper: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    var handleError: (String) -> Void

    @State private var showError = false
    @State private var errorMessage = ""

    private let logger = os.Logger(subsystem: "com.seas3.app", category: "GoogleSignIn")

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
        logger.debug("Google sign-in started.")

        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
                let errMsg = "Unable to find root view controller."
                logger.error("\(errMsg)")
                handleError(errMsg)
                return
        }

        Task {
            do {
                logger.debug("Calling GIDSignIn.sharedInstance.signIn")

                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

                logger.debug("Google sign-in succeeded. User: \(result.user.profile?.email ?? "unknown email", privacy: .public)")

                await authenticationState.completeGoogleSignIn(with: result)

            } catch {
                logger.error("Google sign-in error: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
                showError = true
                handleError(errorMessage)
            }
        }
    }
}
