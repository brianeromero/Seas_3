//
//  LogInView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//

import Foundation
import SwiftUI
import GoogleSignIn
import FBSDKLoginKit

struct LoginView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @State private var showMainContent: Bool = false
    @State private var errorMessage: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var showDisclaimer = false


    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if authenticationState.isAuthenticated && !showMainContent {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.green)
                        Text("Authenticated successfully!")
                            .font(.largeTitle)
                        Button(action: {
                            self.showMainContent = true
                        }) {
                            Text("Continue to Mat Finder")
                                .font(.headline)
                                .padding()
                                .frame(minWidth: 200)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else if showMainContent {
                    IslandMenu()
                } else {
                    VStack(spacing: 20) {
                        Text("Log in or create an account")
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Email address")
                                .font(.subheadline)
                            TextField("Email address", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Text("Password")
                                .font(.subheadline)

                            HStack {
                                if isPasswordVisible {
                                    TextField("Password", text: $password)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                } else {
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }

                                Button(action: {
                                    isPasswordVisible.toggle()
                                }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        NavigationLink(destination: ForgotYourPasswordView()) {
                            Text("Forgot Your Password?")
                                .font(.footnote)
                                .foregroundColor(.blue)
                                .padding(.top, 5)
                        }

                        Button(action: {
                            // Handle login
                        }) {
                            Text("Sign In")
                                .font(.headline)
                                .padding()
                                .frame(minWidth: 335)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(40)
                        }

                        Text("OR")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        VStack(spacing: 5) {
                            GoogleSignInButtonWrapper(handleError: { message in
                                self.errorMessage = message })
                                .frame(height: 50)
                                .clipped()

                            FacebookSignInButtonWrapper(handleError: { message in
                                self.errorMessage = message })
                                .frame(height: 50)
                                .clipped()
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }

                        Text("By continuing, you agree to the updated Terms of Service/Disclaimer")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .underline()
                            .onTapGesture {
                                self.showDisclaimer = true
                            }

                        NavigationLink(destination: DisclaimerView(), isActive: $showDisclaimer) {
                            EmptyView()
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Sign In")
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

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationState())
            .previewDisplayName("Login View")
    }
}
