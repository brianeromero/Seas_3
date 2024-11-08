import Foundation
import FirebaseAuth
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
struct LoginForm: View {
    @Binding var usernameOrEmail: String
    @Binding var password: String
    @Binding var isSignInEnabled: Bool
    @Binding var errorMessage: String
    @EnvironmentObject var authenticationState: AuthenticationState
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @State private var showDisclaimer = false
    @State private var showAdminLogin = false
    @Binding var showMainContent: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isPasswordVisible = false
    @Binding var isLoggedIn: Bool
    @StateObject private var authViewModel = AuthViewModel.shared
    @Binding var navigateToAdminMenu: Bool

    
    // LoginForm
    public init(
        usernameOrEmail: Binding<String>,
        password: Binding<String>,
        isSignInEnabled: Binding<Bool>,
        errorMessage: Binding<String>,
        islandViewModel: PirateIslandViewModel,
        showMainContent: Binding<Bool>,
        isLoggedIn: Binding<Bool>,
        navigateToAdminMenu: Binding<Bool>
    ) {
        _usernameOrEmail = usernameOrEmail
        _password = password
        _isSignInEnabled = isSignInEnabled
        _errorMessage = errorMessage
        self.islandViewModel = islandViewModel
        _showMainContent = showMainContent
        _isLoggedIn = isLoggedIn
        _navigateToAdminMenu = navigateToAdminMenu
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Username or Email")
                .font(.subheadline)
            TextField("Username or Email", text: $usernameOrEmail)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: usernameOrEmail) { newValue in
                    isSignInEnabled = !newValue.isEmpty && !password.isEmpty
                }

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
            .onChange(of: password) { newValue in
                isSignInEnabled = !usernameOrEmail.isEmpty && !newValue.isEmpty
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

        // Validate email if usernameOrEmail is expected to be an email
        if ValidationUtility.validateEmail(usernameOrEmail) != nil {
            // If it's an email, fetch user by email
            do {
                let user = try fetchUser(usernameOrEmail)
                // Here we assume email is non-optional
                let email = user.email // This will be non-optional
                // Sign in with email and password
                Auth.auth().signIn(withEmail: email, password: password) { result, error in
                    if let error = error {
                        showAlert(with: error.localizedDescription)
                    } else {
                        // Handle successful sign-in
                        DispatchQueue.main.async {
                            self.authenticationState.isAuthenticated = true
                            showMainContent = true // Update the main content
                        }
                    }
                }
            } catch {
                showAlert(with: "User not found.")
            }
        } else {
            // Handle username login (assuming your `signInUser` method handles username)
            do {
                try await authViewModel.signInUser(with: usernameOrEmail, password: password) // Updated label
                // Handle successful sign-in
                DispatchQueue.main.async {
                    self.authenticationState.isAuthenticated = true
                    showMainContent = true
                }
            } catch {
                showAlert(with: error.localizedDescription)
            }
        }
    }


    
    private func fetchUser(_ usernameOrEmail: String) throws -> UserInfo {
        let request = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        request.predicate = NSPredicate(format: "userName == %@ OR email == %@", usernameOrEmail, usernameOrEmail)

        let results = try viewContext.fetch(request)
        guard let user = results.first else {
            throw NSError(domain: "User not found", code: 404, userInfo: nil)
        }
        
        // Ensure email is set
        if user.email.isEmpty {
            throw NSError(domain: "User email not found.", code: 404, userInfo: nil)
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
    @StateObject private var authViewModel = AuthViewModel.shared
    @Binding var isLoggedIn: Bool



    // LoginView
    init(islandViewModel: PirateIslandViewModel,
         persistenceController: PersistenceController,
         isSelected: Binding<LoginViewSelection>,
         navigateToAdminMenu: Binding<Bool>,
         isLoggedIn: Binding<Bool>) {
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        self.persistenceController = persistenceController
        self._isSelected = isSelected
        self._navigateToAdminMenu = navigateToAdminMenu
        self._isLoggedIn = isLoggedIn
    }

        
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink(destination: AdminMenu(), isActive: $navigateToAdminMenu) {
                    EmptyView()
                }

                // Use .onAppear to log the authentication state
                .onAppear {
                    // Debug prints to check authentication state
                    print("isAuthenticated: \(authenticationState.isAuthenticated)")
                    print("navigateToAdminMenu: \(authenticationState.navigateToAdminMenu)")
                }

                // Use AnyView to wrap the conditional output
                VStack {
                    if isSelected == .createAccount {
                        CreateAccountView(
                            islandViewModel: islandViewModel,
                            isUserProfileActive: $isUserProfileActive,
                            persistenceController: persistenceController,
                            emailManager: UnifiedEmailManager.shared
                        )
                    } else if authenticationState.isAuthenticated && showMainContent {
                        IslandMenu(
                            persistenceController: self.persistenceController,
                            isLoggedIn: $isLoggedIn, profileViewModel: ProfileViewModel(viewContext: viewContext)
                        )
                    } else if isSelected == .login {
                        VStack(spacing: 20) {
                            HStack(alignment: .center, spacing: 10) {
                                Text("Log In OR")

                                NavigationLink(value: LoginViewSelection.createAccount) {
                                    Text("Create an Account")
                                        .font(.body)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                            }

                            LoginForm(usernameOrEmail: $usernameOrEmail,
                                      password: $password,
                                      isSignInEnabled: $isSignInEnabled,
                                      errorMessage: $errorMessage,
                                      islandViewModel: islandViewModel,
                                      showMainContent: $showMainContent,
                                      isLoggedIn: $isLoggedIn, navigateToAdminMenu: $navigateToAdminMenu)
                                .frame(maxWidth: .infinity)
                                .padding()

                            Spacer()
                        }
                    } else {
                        EmptyView() // Fallback case
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
            .onChange(of: showMainContent) { newValue in
                isLoggedIn = newValue
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
            navigateToAdminMenu: .constant(false),
            isLoggedIn: .constant(false)
        )
    }
}
