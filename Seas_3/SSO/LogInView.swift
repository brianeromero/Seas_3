import Foundation
import CoreData
import SwiftUI
import GoogleSignIn
import FBSDKLoginKit
import Security
import CryptoSwift

enum LoginViewSelection {
    case login
    case createAccount
}

struct LoginView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showMainContent: Bool = false
    @State private var errorMessage: String = ""
    @State private var usernameOrEmail: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var showDisclaimer = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @StateObject private var islandViewModel = PirateIslandViewModel(persistenceController: PersistenceController.shared)
    @State private var isUserProfileActive: Bool = false
    @Binding var isSelected: LoginViewSelection

    let persistenceController: PersistenceController

    init(islandViewModel: PirateIslandViewModel, persistenceController: PersistenceController, isSelected: Binding<LoginViewSelection>) {
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        self.persistenceController = persistenceController
        self._isSelected = isSelected
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if authenticationState.isAuthenticated && !showMainContent {
                    authenticatedView()
                } else if showMainContent {
                    IslandMenu(persistenceController: self.persistenceController)
                } else if isSelected == .login {
                    loginForm()
                } else if isSelected == .createAccount {
                    AccountAuthView(islandViewModel: islandViewModel, isUserProfileActive: $isUserProfileActive)
                }
            }
            .padding()
            .navigationTitle("Sign In")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Authentication Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func authenticatedView() -> some View {
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
    }

    private func loginForm() -> some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 10) {
                Text("Log In or")
                
                NavigationLink(destination: CreateAccountView(
                    islandViewModel: islandViewModel,
                    isUserProfileActive: $isUserProfileActive
                )) {
                    Text("Create an Account")
                        .font(.body)
                        .foregroundColor(.blue)
                        .underline()
                }
            }

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
            
            VStack(spacing: 5) {
                GoogleSignInButtonWrapper(
                    authenticationState: _authenticationState,
                    handleError: { message in
                        self.errorMessage = message
                    },
                    googleClientID: AppConfig.shared.googleClientID
                )
                .frame(height: 50)
                .clipped()
                
                Button(action: {
                    facebookSignIn()
                }) {
                    HStack {
                        Image(systemName: "f.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)
                        Text("Sign in with Facebook")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(minWidth: 335)
                    .background(Color.blue)
                    .cornerRadius(40)
                }
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

    // MARK: - Facebook Sign In Logic
    private func facebookSignIn() {
        FacebookHelper.handleFacebookLogin()
    }
    
    private func fetchProfile() {
        FacebookHelper.fetchFacebookUserProfile { userInfo in
            if let userInfo = userInfo {
                print("Fetched Facebook profile: \(userInfo)")
                authenticationState.isAuthenticated = true
                showMainContent = true
            } else {
                errorMessage = "Failed to fetch Facebook profile."
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isSignInEnabled: Bool {
        return !usernameOrEmail.isEmpty && !password.isEmpty
    }
    
    // MARK: - Sign In Logic
    private func signIn() {
        guard let user = fetchUser(usernameOrEmail) else {
            alertMessage = "That username/email address doesn't exist in our records."
            showAlert = true
            return
        }

        do {
            let storedPasswordHash = try fetchStoredPasswordHash(usernameOrEmail)
            _ = try hashPasswordPbkdf(password)
            
            if try verifyPasswordPbkdf(password, againstHash: storedPasswordHash) {
                print("Password is valid")
                authenticationState.isAuthenticated = true
                authenticationState.user = user
                showMainContent = true
            } else {
                alertMessage = "Incorrect password."
                showAlert = true
            }
        } catch {
            print("Error during password processing: \(error)")
            alertMessage = "An error occurred while signing in."
            showAlert = true
        }
    }
    
    // Fetch stored password hash from Core Data
    private func fetchStoredPasswordHash(_ identifier: String) throws -> HashedPassword {
        // Implement Core Data fetch logic here
        // Replace with actual implementation
        let storedPasswordHash = HashedPassword(salt: Data(), iterations: 0, hash: Data())
        return storedPasswordHash
    }
    
    private func fetchUser(_ identifier: String) -> UserInfo? {
        let fetchRequest = UserInfo.fetchRequest()
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "email == %@", identifier),
            NSPredicate(format: "username == %@", identifier)
        ])

        do {
            let users = try viewContext.fetch(fetchRequest)
            return users.first
        } catch {
            print("Error fetching user: \(error)")
            return nil
        }
    }
}


struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(
            islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
            persistenceController: PersistenceController.shared,
            isSelected: .constant(.login)
        )
        .environmentObject(AuthenticationState())
        .previewDisplayName("Login View")
    }
}
