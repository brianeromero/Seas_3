//
//  GoogleSignInButton.swift
//  Seas_3
//
//  Created by Brian Romero on 10/3/24.
//

import Foundation
import GoogleSignInSwift
import SwiftUI
import GoogleSignIn
import GoogleSignInSwift


struct GoogleSignInButtonView: View {
    var body: some View {
        Button(action: {
            guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
                return
            }

            Task {
                do {
                    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
                    // Handle sign in result
                    print("Google Sign-In successful")
                } catch {
                    print("Google Sign-In error: \(error.localizedDescription)")
                }
            }
        }) {
            Text("Sign in with Google")
                .frame(height: 50)
                .padding()
        }
    }
}
