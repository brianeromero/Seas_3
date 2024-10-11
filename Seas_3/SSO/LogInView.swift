<<<<<<< HEAD
import Foundation
import CoreData
=======
//
//  LogInView.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//

import Foundation
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
import SwiftUI
import GoogleSignIn
import FBSDKLoginKit

struct LoginView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
<<<<<<< HEAD
    @Environment(\.managedObjectContext) private var viewContext
=======
    @Environment(\.managedObjectContext) private var viewContext // Inject the Core Data context
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
    @State private var showMainContent: Bool = false
    @State private var errorMessage: String = ""
    @State private var usernameOrEmail: String = "" // Changed from email to usernameOrEmail
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var showDisclaimer = false
    @State private var showAlert = false
    @State private var alertMessage = ""
<<<<<<< HEAD
    @StateObject var islandViewModel: PirateIslandViewModel

    // Add a property for PirateIslandViewModel
    let context: NSManagedObjectContext

    init(islandViewModel: PirateIslandViewModel, context: NSManagedObjectContext) {
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        self.context = context
    }
=======
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9

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
<<<<<<< HEAD
                        HStack(alignment: .center, spacing: 10) {
                            Text("Log In or")
                            NavigationLink(destination: AccountCreationFormView(islandViewModel: PirateIslandViewModel(context: context), context: context)) {
                                Text("Create an Account")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                        }
=======
                        Text("Log in or create an account")
                            .font(.title3)
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Username or Email")
                                .font(.subheadline)
                            TextField("Username or Email", text: $usernameOrEmail)
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

                        // Sign In Button
                        Button(action: {
                            signIn()
                        }) {
                            Text("Sign In")
                                .font(.headline)
                                .padding()
                                .frame(minWidth: 335)
                                .background(isSignInEnabled ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(40)
                        }
                        .disabled(!isSignInEnabled)

                        Text("OR")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        // Show other sign-in options
                        VStack(spacing: 5) {
                            GoogleSignInButtonWrapper(handleError: { message in
<<<<<<< HEAD
                                self.errorMessage = message
                            })
                            .frame(height: 50)
                            .clipped()

                            FacebookSignInButtonWrapper(handleError: { message in
                                self.errorMessage = message
                            })
                            .frame(height: 50)
                            .clipped()
=======
                                self.errorMessage = message })
                                .frame(height: 50)
                                .clipped()

                            FacebookSignInButtonWrapper(handleError: { message in
                                self.errorMessage = message })
                                .frame(height: 50)
                                .clipped()
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
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
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Authentication Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Computed Properties
    private var isSignInEnabled: Bool {
        return !usernameOrEmail.isEmpty && !password.isEmpty // Enable if both fields are filled
    }

    // MARK: - Sign In Logic
    private func signIn() {
        guard let user = fetchUser(usernameOrEmail) else {
            alertMessage = "That username/email address doesn't exist in our records."
            showAlert = true
            return
        }

        // Pass the entire PasswordHash object to the verifyPassword function.
        if let passwordHash = user.passwordHash {
            // Debug print to log the details of the PasswordHash object
            print("Password hash details: \(passwordHash)")
            
            // Directly pass PasswordHash to verifyPassword
            if ((try? verifyPassword(password, againstHash: passwordHash)) != nil) {
                alertMessage = "You exist. Welcome."
                showMainContent = true
            } else {
                alertMessage = "That username/email address and password don't match."
            }
        } else {
            alertMessage = "User password hash is missing."
        }

        showAlert = true
    }

<<<<<<< HEAD
=======

>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
    // Fetch user based on email
    private func fetchUser(_ identifier: String) -> User? {
        // Replace this with actual data fetching logic (from a database or API)
        let mockUsers: [User] = [
            User(email: "user@example.com", username: "user123", passwordHash: try? hashPassword("correctPassword")),
            User(email: "admin@example.com", username: "adminUser", passwordHash: try? hashPassword("adminPass")),
            User(email: "username123@example.com", username: "username123", passwordHash: try? hashPassword("password123"))
        ]
        
        // Check for user by email or username
        return mockUsers.first { $0.email == identifier || $0.username == identifier }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
<<<<<<< HEAD
        let context = PersistenceController.shared.viewContext
        LoginView(islandViewModel: PirateIslandViewModel(context: context), context: context)
=======
        LoginView()
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
            .environmentObject(AuthenticationState())
            .previewDisplayName("Login View")
    }
}
