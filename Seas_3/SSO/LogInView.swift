//
//  LogInView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/3/24.
//

import Foundation
import SwiftUI
import GoogleSignIn


// LoginView.swift
struct LoginView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @State private var showMainContent: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack {
            if authenticationState.isAuthenticated && !showMainContent {
                Text("Authenticated successfully!")
                    .font(.largeTitle)
                Button(action: {
                    self.showMainContent = true
                }) {
                    Text("Continue to Mat Finder")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else if showMainContent {
                IslandMenu()
            } else {
                VStack {
                    Text("Welcome to Mat_Finder!")
                        .font(.largeTitle)
                        .padding(.bottom, 20)

                    Text("Please sign in to continue")
                        .font(.subheadline)
                        .padding(.bottom, 40)

                    GoogleSignInButtonWrapper { message in
                        self.errorMessage = message
                    }
                    .frame(height: 50)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }

                    Text("or sign in with")
                        .font(.subheadline)
                        .padding(.vertical)
                }
                .padding()
                .background(Color.white)
            }
        }
        .onChange(of: authenticationState.isAuthenticated) { newValue in
            print("Authentication state changed: \(newValue)")
            if newValue {
                print("Showing main content")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showMainContent = true
                }
            }
        }
    }
}


// GoogleSignInButtonWrapper.swift
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
                self.parent.authenticationState.isAuthenticated = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationState())
    }
}
