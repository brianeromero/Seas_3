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
    let googleClientID: String?

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
        var parent: GoogleSignInButtonWrapper?
        let googleClientID: String
        let googleScopes: [String] = []  // Add scopes if needed

        init(_ parent: GoogleSignInButtonWrapper) {
            self.parent = parent
            self.googleClientID = parent.googleClientID ?? ""
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

            // Configure Google Sign-In
            _ = GIDConfiguration(clientID: googleClientID)

            // Start Google Sign-In process with error handling
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: googleScopes) { [weak self] result, error in
                guard let self = self else { return }
                if let error = error {
                    print("Google Sign-In error: \(error.localizedDescription)")
                    if let parent = self.parent {
                        parent.handleError(error.localizedDescription)
                    } else {
                        print("Parent is nil")
                    }
                    return
                }
                
                // Handle successful sign-in
                print("Google Sign-In successful")
                if let user = result?.user {
                    let userID = user.userID ?? ""
                    let userName = user.profile?.name ?? ""
                    let userEmail = user.profile?.email ?? ""
                    
                    do {
                        try self.parent?.authenticationState.updateSocialUser(.google, userID, userName, userEmail)
                    } catch {
                        print("Error updating social user: \(error.localizedDescription)")
                        if let parent = self.parent {
                            parent.handleError(error.localizedDescription)
                        } else {
                            print("Parent is nil")
                        }
                    }
                }
            }
        }
    }
}

struct GoogleSignInButtonWrapper_Previews: PreviewProvider {
    @StateObject static var authenticationState = AuthenticationState()
    
    static var previews: some View {
        GoogleSignInButtonWrapper(
            handleError: { message in
                print("Error: \(message)")
            },
            googleClientID: AppConfig.shared.googleClientID
        )
        .environmentObject(authenticationState)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
