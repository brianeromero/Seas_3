/*
//
//  GoogleSignInButton.swift
//  Seas_3
//
//  Created by Brian Romero on 10/3/24.
//

import Foundation
import SwiftUI
import GoogleSignInSwift


struct GoogleSignInButtonView: View {
    var body: some View {
        Button(action: {
            guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                .windows.first?.rootViewController else {
                print("❌ No presenting view controller")
                return
            }

            Task {
                do {
                    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
                    print("✅ Google Sign-In successful for: \(result.user.profile?.email ?? "Unknown email")")

                    guard let idToken = result.user.idToken?.tokenString else {
                        print("❌ No ID Token returned")
                        return
                    }

                    let accessToken = result.user.accessToken.tokenString

                    print("🧾 ID Token:\n\(idToken)\n")
                    print("🧾 Access Token:\n\(accessToken)\n")

                    // Optionally: sign in to Firebase
                    let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                    try await Auth.auth().signIn(with: credential)
                    print("✅ Firebase sign-in successful")

                } catch {
                    print("❌ Google Sign-In error: \(error.localizedDescription)")
                }
            }
        }) {
            Text("Sign in with Google")
                .frame(height: 50)
                .padding()
        }
    }
}
*/
