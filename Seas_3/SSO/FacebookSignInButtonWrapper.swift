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
    var fetchFacebookUserProfile: ((@escaping ([String: Any]?) -> Void) -> Void)?
    let facebookAppID: String?

    
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
        context.coordinator.signOutButton.isHidden = true

        view.addSubview(context.coordinator.signInButton)
        view.addSubview(context.coordinator.signOutButton)

        context.coordinator.signInButton.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.signOutButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            context.coordinator.signInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            context.coordinator.signInButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            context.coordinator.signInButton.widthAnchor.constraint(equalToConstant: 335),
            context.coordinator.signInButton.heightAnchor.constraint(equalToConstant: 45),

            context.coordinator.signOutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            context.coordinator.signOutButton.topAnchor.constraint(equalTo: context.coordinator.signInButton.bottomAnchor, constant: 20),
            context.coordinator.signOutButton.widthAnchor.constraint(equalToConstant: 250),
            context.coordinator.signOutButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        if let appId = facebookAppID {
            print("Facebook App ID: \(appId)")
        } else {
            print("Facebook App ID not found FBSIGNBUTWRAP")
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
        
        let facebookPermissions = ["public_profile", "email"]

        
        @objc func signIn() {
            print("Facebook Sign-In initiated")

            let loginManager = LoginManager()
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                guard let window = scene.windows.first else { return }

                loginManager.logIn(permissions: facebookPermissions, from: window.rootViewController) { [weak self] result, error in
                    if let error = error {
                        FacebookHelper.handleFacebookSDKError(error)
                        self?.parent.handleError(error.localizedDescription)
                        return
                    }

                    if result?.isCancelled ?? false {
                        print("User cancelled Facebook login")
                    } else {
                        // Successfully logged in, fetch the profile
                        FacebookHelper.fetchFacebookUserProfile { userInfo in
                            guard let userInfo = userInfo,
                                  let email = userInfo["email"] as? String,
                                  let name = userInfo["name"] as? String,
                                  let id = userInfo["id"] as? String else {
                                print("User info is nil or doesn't contain required fields.")
                                return
                            }
                            // Update state with the user info
                            self?.parent.authenticationState.objectWillChange.send()
                            try? self?.parent.authenticationState.updateSocialUser(.facebook, id, name, email)
                        }
                    }
                }
            }
        }


        @objc func signOut() {
            let loginManager = LoginManager()
            loginManager.logOut()

            parent.authenticationState.resetSocialUser()

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
        PreviewView()
    }
}

struct FacebookSignInButtonWrapper_Previews_PreviewView: View {
    @StateObject var authenticationState = AuthenticationState()
    
    var body: some View {
        FacebookSignInButtonWrapper(
            handleError: { message in
                print("Error: \(message)")
            },
            fetchFacebookUserProfile: nil,
            facebookAppID: AppConfig.shared.facebookAppID
        )
        .environmentObject(authenticationState)
        .frame(width: 400, height: 300)
        .previewDisplayName("Facebook Sign-In Button Preview")
    }
}
