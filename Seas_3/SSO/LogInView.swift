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

// Extracted login form view
// Extracted login form view
struct LoginForm: View {
    @Binding var usernameOrEmail: String
    @Binding var password: String
    @Binding var isSignInEnabled: Bool
    @Binding var errorMessage: String
    @EnvironmentObject var authenticationState: AuthenticationState
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @State private var showDisclaimer = false
    @State private var showAdminLogin = false
    @State private var navigateToAdminMenu = false
    @Binding var showMainContent: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isPasswordVisible: Bool = false
    
    public init(usernameOrEmail: Binding<String>,
                password: Binding<String>,
                isSignInEnabled: Binding<Bool>,
                errorMessage: Binding<String>,
                islandViewModel: PirateIslandViewModel,
                showMainContent: Binding<Bool>) {
        _usernameOrEmail = usernameOrEmail
        _password = password
        _isSignInEnabled = isSignInEnabled
        _errorMessage = errorMessage
        self.islandViewModel = islandViewModel
        _showMainContent = showMainContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Username or Email")
                .font(.subheadline)
            TextField("Username or Email", text: $usernameOrEmail)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Text("Password")
                .font(.subheadline)
            
            // Updated Password Field with Visibility Toggle
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
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Button(action: {
                Task {
                    await signIn()
                }
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

            // Google Sign-In Button
            GoogleSignInButtonWrapper(
                authenticationState: _authenticationState,
                handleError: { message in
                    self.errorMessage = message
                },
                googleClientID: AppConfig.shared.googleClientID
            )
            .frame(height: 50)
            .clipped()

            // Facebook Sign-In Button
            FacebookSignInButtonWrapper(
                authenticationState: _authenticationState,
                handleError: { message in
                    self.errorMessage = message
                }
            )
            .frame(height: 50)
            .clipped()
            .frame(height: 50)
            .clipped()

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red)
            }

            Text("By continuing, you agree to the updated Terms of Service/Disclaimer")
                .font(.footnote)
                .foregroundColor(.secondary)
                .underline()
                .onTapGesture {
                    self.showDisclaimer = true
                }
                .navigationDestination(isPresented: $showDisclaimer) {
                    DisclaimerView()
                }

            // Admin Login Button
            Button(action: {
                showAdminLogin.toggle()
            }) {
                Text("Admin Login")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            .sheet(isPresented: $showAdminLogin) {
                AdminLoginView(isPresented: $showAdminLogin, navigateToAdminMenu: $navigateToAdminMenu)
            }
        }
    }

    // MARK: - Facebook Sign In Logic
    private func facebookSignIn() {
        FacebookHelper.handleFacebookLogin()
    }

    // MARK: - Sign In Logic
    private func signIn() async {
        guard !usernameOrEmail.isEmpty && !password.isEmpty else {
            showAlert(with: "Please enter both username and password.")
            return
        }

        do {
            let user = try fetchUser(usernameOrEmail)
            guard user.isVerified else {
                showAlert(with: "User not found or email unverified.")
                return
            }

            let storedPasswordHash = try AuthenticationHelper.fetchStoredUserHash(context: viewContext, identifier: usernameOrEmail)
            let isPasswordValid = try AuthenticationHelper.verifyUserPassword(inputPassword: password, storedHash: storedPasswordHash)

            if isPasswordValid {
                authenticationState.isAuthenticated = true
                showMainContent = true
            } else {
                showAlert(with: "Incorrect password.")
            }
        } catch {
            showAlert(with: "An unexpected error occurred.")
        }
    }

    private func fetchUser(_ usernameOrEmail: String) throws -> UserInfo {
        let request = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        request.predicate = NSPredicate(format: "userName == %@ OR email == %@", usernameOrEmail, usernameOrEmail)

        let results = try viewContext.fetch(request)
        guard let user = results.first else {
            throw NSError(domain: "User not found", code: 404, userInfo: nil)
        }
        return user
    }

    // Alert Helper
    private func showAlert(with message: String) {
        errorMessage = message
    }
}

struct LoginView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showMainContent: Bool = false
    @State private var errorMessage: String = ""
    @State private var usernameOrEmail: String = ""
    @State private var password: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDisclaimer = false
    @State private var showAdminLogin = false
    @StateObject private var islandViewModel: PirateIslandViewModel
    @State private var isUserProfileActive: Bool = false
    @Binding var isSelected: LoginViewSelection
    @Binding var navigateToAdminMenu: Bool
    let persistenceController: PersistenceController
    @State private var createAccountLinkActive = false
    @State private var isSignInEnabled: Bool = false

    init(islandViewModel: PirateIslandViewModel,
         persistenceController: PersistenceController,
         isSelected: Binding<LoginViewSelection>,
         navigateToAdminMenu: Binding<Bool>) {
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        self.persistenceController = persistenceController
        self._isSelected = isSelected
        self._navigateToAdminMenu = navigateToAdminMenu
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink(destination: AdminMenu(), isActive: $navigateToAdminMenu) {
                    EmptyView()
                }

                if isSelected == .createAccount {
                    CreateAccountView(
                        islandViewModel: islandViewModel,
                        isUserProfileActive: $isUserProfileActive,
                        persistenceController: persistenceController,
                        emailManager: UnifiedEmailManager.shared
                    )
                } else if authenticationState.isAuthenticated && showMainContent {
                    IslandMenu(persistenceController: self.persistenceController)
                } else if isSelected == .login {
                    VStack(spacing: 20) {
                        HStack(alignment: .center, spacing: 10) {
                            Text("Log In OR")

                            // Updated NavigationLink for Create Account
                            NavigationLink(value: LoginViewSelection.createAccount) {
                                Text("Create an Account")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                        }

                        // Centered LoginForm
                        LoginForm(usernameOrEmail: $usernameOrEmail,
                                  password: $password,
                                  isSignInEnabled: $isSignInEnabled,
                                  errorMessage: $errorMessage,
                                  islandViewModel: islandViewModel,
                                  showMainContent: $showMainContent)
                            .frame(maxWidth: .infinity)
                            .padding()

                        Spacer()
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .padding()
            .navigationDestination(for: LoginViewSelection.self) { selection in
                switch selection {
                case .createAccount:
                    CreateAccountView(
                        islandViewModel: islandViewModel,
                        isUserProfileActive: $isUserProfileActive,
                        persistenceController: persistenceController,
                        emailManager: UnifiedEmailManager.shared
                    )
                case .login:
                    EmptyView()
                }
            }
        }
    }
}



struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(
            islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
            persistenceController: PersistenceController.shared,
            isSelected: .constant(.login),
            navigateToAdminMenu: .constant(false)
        )
    }
}
