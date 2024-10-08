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

struct FacebookSignInButtonWrapper: UIViewRepresentable {
    @EnvironmentObject var authenticationState: AuthenticationState
    var handleError: (String) -> Void

    // Add a sign-out button
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .white

        context.coordinator.signInButton = UIButton(type: .system)
        context.coordinator.signInButton.setTitle("Sign in with Facebook", for: .normal)
        context.coordinator.signInButton.setTitleColor(.white, for: .normal)
        context.coordinator.signInButton.backgroundColor = .facebookBlue
        context.coordinator.signInButton.layer.cornerRadius = 5
        context.coordinator.signInButton.addTarget(context.coordinator, action: #selector(context.coordinator.signIn), for: .touchUpInside)

        context.coordinator.signOutButton = UIButton(type: .system)
        context.coordinator.signOutButton.setTitle("Sign out", for: .normal)
        context.coordinator.signOutButton.setTitleColor(.white, for: .normal)
        context.coordinator.signOutButton.backgroundColor = .facebookBlue
        context.coordinator.signOutButton.layer.cornerRadius = 5
        context.coordinator.signOutButton.addTarget(context.coordinator, action: #selector(context.coordinator.signOut), for: .touchUpInside)
        context.coordinator.signOutButton.isHidden = true // Hide sign-out button initially

        view.addSubview(context.coordinator.signInButton)
        view.addSubview(context.coordinator.signOutButton)

        // Configure button constraints...
        context.coordinator.signInButton.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.signOutButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            context.coordinator.signInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            context.coordinator.signInButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            context.coordinator.signInButton.widthAnchor.constraint(equalToConstant: 335), // Increased width
            context.coordinator.signInButton.heightAnchor.constraint(equalToConstant: 45), // Added height constraint

            context.coordinator.signOutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            context.coordinator.signOutButton.topAnchor.constraint(equalTo: context.coordinator.signInButton.bottomAnchor, constant: 20),
            context.coordinator.signOutButton.widthAnchor.constraint(equalToConstant: 250), // Increased width
            context.coordinator.signOutButton.heightAnchor.constraint(equalToConstant: 60)  // Added height constraint
        ])


        // Check for Facebook App ID
        if let appId = Settings.shared.appID {
            print("Facebook App ID: \(appId)")
        } else {
            print("Facebook App ID not found")
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: FacebookSignInButtonWrapper
        var signInButton: UIButton!
        var signOutButton: UIButton!
        let locationManager = CLLocationManager()

        init(_ parent: FacebookSignInButtonWrapper) {
            self.parent = parent
            super.init()
            locationManager.delegate = self
        }

        @objc func signIn() {
            print("Facebook Sign-In initiated")

            let loginManager = LoginManager()
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                guard let window = scene.windows.first else {
                    return
                }

                loginManager.logIn(permissions: ["public_profile", "email"], from: window.rootViewController) { [weak self] result, error in
                    if let error = error {
                        self?.parent.handleError(error.localizedDescription)
                        return
                    }

                    if result?.isCancelled ?? true {
                        self?.parent.handleError("User cancelled Facebook login")
                        return
                    }

                    GraphRequest(graphPath: "me", parameters: ["fields": "id, name, email"]).start { [weak self] connection, result, error in
                        if let error = error {
                            self?.parent.handleError(error.localizedDescription)
                            return
                        }

                        guard let resultDict = result as? [String: Any] else {
                            self?.parent.handleError("Invalid Graph API response")
                            return
                        }

                        // Extract user data
                        let userId = resultDict["id"] as? String
                        let userName = resultDict["name"] as? String
                        let userEmail = resultDict["email"] as? String

                        // Update authentication state or perform other actions
                        self?.parent.authenticationState.updateFacebookUser(userId, userName, userEmail)

                        // Show sign-out button after signing in
                        self?.signOutButton.isHidden = false
                        self?.signInButton.isHidden = true
                    }
                }
            }
        }

        @objc func signOut() {
            let loginManager = LoginManager()
            loginManager.logOut()

            // Update authentication state
            parent.authenticationState.resetFacebookUser()

            // Hide sign-out button after signing out
            signOutButton.isHidden = true
            signInButton.isHidden = false
        }
    }
}

extension FacebookSignInButtonWrapper.Coordinator: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        parent.handleError(error.localizedDescription)
    }
}

extension UIColor {
    static let facebookBlue = UIColor(red: 23/255, green: 118/255, blue: 255/255, alpha: 1)
}



struct FacebookSignInButtonWrapper_Previews: PreviewProvider {
    static var previews: some View {
        FacebookSignInButtonWrapper { errorMessage in
            print("Error: \(errorMessage)")
        }
        .environmentObject(AuthenticationState()) // Add the required environment object
        .frame(width: 400, height: 300) // Adjust frame size for the preview
        .previewDisplayName("Facebook Sign-In Button Preview")
    }
}
