
//
//  GoogleSignInButtonWrapper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//

import Foundation
import SwiftUI
import GoogleSignInSwift
import CoreData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

import SwiftUI
import GoogleSignIn



struct GoogleSignInButtonWrapper: UIViewRepresentable {
    @EnvironmentObject var authenticationState: AuthenticationState
    var handleError: (String) -> Void

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.addTarget(context.coordinator, action: #selector(Coordinator.signIn), for: .touchUpInside)
        print("[GoogleSignInButtonWrapper] GIDSignInButton created and target added.")
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {
        // Add logs here if/when UI updates are required
    }

    func makeCoordinator() -> Coordinator {
        print("[GoogleSignInButtonWrapper] Coordinator created.")
        return Coordinator(authenticationState: authenticationState, handleError: handleError)
    }

    @MainActor
    class Coordinator: NSObject {
        var authenticationState: AuthenticationState
        var handleError: (String) -> Void

        init(authenticationState: AuthenticationState, handleError: @escaping (String) -> Void) {
            self.authenticationState = authenticationState
            self.handleError = handleError
            print("[Coordinator] Initialized with AuthenticationState.")
        }

        @objc func signIn() {
            print("🔵 Initiating Google Sign-In process...")

            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }),
                  let rootVC = window.rootViewController else {
                print("❌ Could not get rootViewController for sign-in presentation.")
                handleError("Unable to initiate Google Sign-In.")
                return
            }

            Task {
                do {
                    print("[Coordinator] Presenting Google Sign-In...")
                    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                    print("✅ Google Sign-In successful for: \(result.user.profile?.email ?? "unknown email")")

                    // Pass the user to your AuthenticationState or use tokens
                    await authenticationState.completeGoogleSignIn(with: result)

                } catch {
                    print("❌ Google Sign-In failed: \(error.localizedDescription)")
                    handleError("Google Sign-In failed: \(error.localizedDescription)")
                }
            }
        }

    }
}


struct GoogleSignInButtonWrapper_Previews: PreviewProvider {
    static var previews: some View {
        let authenticationState = AuthenticationState(hashPassword: HashPassword())
        return GoogleSignInButtonWrapper(
            handleError: { message in
                print("Error: \(message)")
            }
        )
        .environmentObject(authenticationState)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
