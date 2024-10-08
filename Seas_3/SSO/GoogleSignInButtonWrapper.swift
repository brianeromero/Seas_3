//
//  GoogleSignInButtonWrapper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//
import Foundation
import SwiftUI
import GoogleSignIn

struct GoogleSignInButtonWrapper: UIViewRepresentable {
    @EnvironmentObject var authenticationState: AuthenticationState
    var handleError: (String) -> Void

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.addTarget(context.coordinator, action: #selector(context.coordinator.signIn), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: GoogleSignInButtonWrapper

        init(_ parent: GoogleSignInButtonWrapper) {
            self.parent = parent
            super.init()
        }

        @objc func signIn() {
            print("Google Sign-In initiated")

            // Get the root view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("No root view controller available")
                return
            }

            // Start Google Sign-In process with error handling
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { user, error in
                if let error = error {
                    print("Google Sign-In error: \(error.localizedDescription)")
                    self.parent.handleError(error.localizedDescription)
                    return
                }
                
                // Handle successful sign-in
                print("Google Sign-In successful")
                self.parent.authenticationState.updateGoogleUser()
            }
        }
    }
}


struct GoogleSignInButtonWrapper_Previews: PreviewProvider {
    static var previews: some View {
        GoogleSignInButtonWrapper(handleError: { message in
            print("Error: \(message)")
        })
        .environmentObject(AuthenticationState())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
