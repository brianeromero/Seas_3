//
//  FacebookSignInButtonWrapper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//

import Foundation
import SwiftUI
import FBSDKLoginKit
import FBSDKCoreKit
import CoreLocation
import AuthenticationServices
import FacebookLogin
import FirebaseAuth


struct FacebookSignInButtonWrapper: UIViewRepresentable {
    @EnvironmentObject var authenticationState: AuthenticationState
    var handleError: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        print("Creating Facebook Sign-In button...")
        let view = UIView()
        let loginButton = FBLoginButton()
        loginButton.delegate = context.coordinator
        loginButton.permissions = ["public_profile", "email"]

        view.addSubview(loginButton)
        loginButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        print("Facebook Sign-In button added to view.")
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        print("Updating Facebook Sign-In button view...")
    }

    func makeCoordinator() -> Coordinator {
        print("Creating FacebookSignInButtonWrapper Coordinator...")
        return Coordinator(self)
    }

    class Coordinator: NSObject, LoginButtonDelegate {
        var parent: FacebookSignInButtonWrapper?   
        
        init(_ parent: FacebookSignInButtonWrapper) {
            self.parent = parent
            print("✅ Facebook Coordinator initialized.")
        }

        func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
            print("🔹 Facebook login button pressed.")

            if let error = error {
                print("❌ Facebook login error: \(error.localizedDescription)")
                parent?.handleError(error.localizedDescription)
                return
            }

            guard let result = result, let token = result.token else {
                print("❌ Facebook login failed or was cancelled.")
                parent?.handleError("Facebook login was unsuccessful.")
                return
            }

            print("✅ Facebook login successful. Access Token: \(token.tokenString)")

            // Use the FacebookHelper to handle the login flow
            let authManager = AuthenticationManager()
            FacebookHelper.handleFacebookLogin(authManager: authManager)  // This handles token validation and Firebase authentication
        }


        func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
            print("🔹 User logged out from Facebook.")
            parent?.authenticationState.logout()

            AccessToken.current = nil
            
            let loginManager = LoginManager()
            loginManager.logOut()

            DispatchQueue.main.async {
                guard let superview = loginButton.superview else { return }
                
                loginButton.removeFromSuperview()

                let newButton = FBLoginButton()
                newButton.delegate = self
                newButton.permissions = ["public_profile", "email"]
                
                superview.addSubview(newButton)
                
                newButton.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    newButton.centerXAnchor.constraint(equalTo: superview.centerXAnchor),
                    newButton.centerYAnchor.constraint(equalTo: superview.centerYAnchor)
                ])
                
                print("✅ Facebook login button reloaded.")
            }
        }
    }
}


struct FacebookSignInButtonWrapper_Previews: PreviewProvider {
    static var previews: some View {
        let authenticationState = AuthenticationState(hashPassword: HashPassword())
        return FacebookSignInButtonWrapper(
            handleError: { message in
                print("Error: \(message)")
            }
        )
        .environmentObject(authenticationState)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
