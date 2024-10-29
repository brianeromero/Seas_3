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

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .white

        let loginButton = FBLoginButton()
        loginButton.delegate = context.coordinator
        loginButton.permissions = ["public_profile", "email"]

        view.addSubview(loginButton)

        loginButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loginButton.widthAnchor.constraint(equalToConstant: 335),
            loginButton.heightAnchor.constraint(equalToConstant: 45)
        ])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, LoginButtonDelegate {
        var parent: FacebookSignInButtonWrapper?

        init(_ parent: FacebookSignInButtonWrapper) {
            self.parent = parent
            super.init()
        }

        func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
            guard let result = result, result.isCancelled == false else {
                print("User cancelled login.")
                return
            }

            if let error = error {
                FacebookHelper.handleFacebookSDKError(error)
                parent?.handleError(error.localizedDescription)
                print("Facebook login error: \(error.localizedDescription)")
                return
            }

            FacebookHelper.fetchFacebookUserProfile { [weak self] userInfo in
                guard let self = self,
                      let userInfo = userInfo,
                      let email = userInfo["email"] as? String,
                      let name = userInfo["name"] as? String,
                      let id = userInfo["id"] as? String else {
                    print("Invalid user info.")
                    return
                }

                try? self.parent?.authenticationState.updateSocialUser(.facebook, id, name, email)
            }
        }

        func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
            parent?.authenticationState.resetSocialUser()
            print("User signed out")
        }
    }
}
