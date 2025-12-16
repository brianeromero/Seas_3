//
//  GoogleSignInButtonWrapper.swift
//  Mat_Finder
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
import os.log

import SwiftUI

struct GoogleSignInButtonWrapper: View {
    @ObservedObject private var authViewModel = AuthViewModel.shared

    let onSuccess: () -> Void
    let onError: (String) -> Void

    @State private var showError = false
    @State private var errorMessage = ""

    private let logger = os.Logger(
        subsystem: "com.mat_Finder.app",
        category: "GoogleSignIn"
    )

    var body: some View {
        Button(action: handleSignIn) {
            Image("google_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func handleSignIn() {
        logger.debug("Google sign-in started from button wrapper.")

        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {

            let errMsg = "Unable to find root view controller for Google Sign-In."
            logger.error("\(errMsg, privacy: .public)")
            onError(errMsg)
            return
        }

        Task {
            await authViewModel.signInWithGoogle(presenting: rootVC)

            await MainActor.run {
                if let vmError = authViewModel.errorMessage, !vmError.isEmpty {
                    onError(vmError)
                    authViewModel.errorMessage = ""
                } else {
                    // ✅ LOGIN SUCCEEDED
                    onSuccess()
                }
            }
        }
    }
}
