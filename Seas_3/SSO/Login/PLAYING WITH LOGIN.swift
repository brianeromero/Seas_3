import Foundation
import FirebaseAuth
import CoreData
import SwiftUI
import GoogleSignIn
import FBSDKLoginKit
import Security
import CryptoSwift

enum LoginViewSelectionLoginViewSelection: Int {
    case login
    case createAccount
}

// Extracted login form view
struct LoginFormLoginForm: View {
    @Binding var usernameOrEmail: String
    @StateObject private var authViewModel = AuthViewModel()
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
    @Binding var navigateToAdminMenu: Bool
    @FocusState private var focusedField: Field?

    enum Field {
        case usernameOrEmail
        case password
    }
    
    
    init(
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
        VStack(alignment: .leading, spacing: 20) {

            // Left-aligned fields: Username or Email & Password
            VStack(alignment: .leading, spacing: 20) {
                Text("Username or Email")
                    .font(.headline)
                TextField("Username or Email", text: $usernameOrEmail)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: usernameOrEmail) { newValue in
                        isSignInEnabled = !newValue.isEmpty && !password.isEmpty
                    }

                Text("Password")
                    .font(.headline)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Left-align these fields

            // Centered Sign In Button, Text, and Admin Login
            VStack(spacing: 20) {
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

                HStack {
                    GoogleSignInButtonWrapper(
                        authenticationState: _authenticationState,
                        handleError: { message in
                            self.errorMessage = message
                        },
                        googleClientID: AppConfig.shared.googleClientID,
                        managedObjectContext: viewContext  // Pass the existing viewContext
                    )
                    .frame(height: 50)
                    .clipped()

                    FacebookSignInButtonWrapper(
                        authenticationState: _authenticationState,
                        handleError: { message in
                            self.errorMessage = message
                        }
                    )
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
                    .navigationDestination(isPresented: $showDisclaimer) {
                        DisclaimerView()
                    }

                Button(action: {
                    showAdminLogin.toggle()
                }) {
                    Text("Admin Login")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showAdminLogin) {
                    AdminLoginView(isPresented: $showAdminLogin)

                }
            }
            .frame(maxWidth: .infinity, alignment: .center) // Center-align these views
        }
        .padding()
    }
    
    // MARK: - Helper Functions

    private func updateSignInEnabled() {
        isSignInEnabled = !usernameOrEmail.isEmpty && !password.isEmpty
    }

    private func signIn() async {
        guard !usernameOrEmail.isEmpty && !password.isEmpty else {
            showAlert(with: "Please enter both username and password.")
            return
        }

        if ValidationUtility.validateEmail(usernameOrEmail) != nil {
            do {
                let user = try fetchUser(usernameOrEmail)
                let email = user.email
                Auth.auth().signIn(withEmail: email, password: password) { result, error in
                    if let error = error {
                        showAlert(with: error.localizedDescription)
                    } else {
                        DispatchQueue.main.async {
                            self.authenticationState.isAuthenticated = true
                            showMainContent = true
                        }
                    }
                }
            } catch {
                showAlert(with: "User not found.")
            }
        } else {
            do {
                try await authViewModel.signInUser(with: usernameOrEmail, password: password)
                DispatchQueue.main.async {
                    self.authenticationState.isAuthenticated = true
                    showMainContent = true
                }
            } catch {
                showAlert(with: error.localizedDescription)
            }
        }
    }

    // MARK: - Fetch User
    private func fetchUser(_ usernameOrEmail: String) throws -> UserInfo {
        let request = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        request.predicate = NSPredicate(format: "userName == %@ OR email == %@", usernameOrEmail, usernameOrEmail)

        let results = try viewContext.fetch(request)
        guard let user = results.first else {
            throw NSError(domain: "User not found", code: 404, userInfo: nil)
        }

        if user.email.isEmpty {
            throw NSError(domain: "User email not found.", code: 404, userInfo: nil)
        }

        return user
    }

    // MARK: - Alert Helper
    private func showAlert(with message: String) {
        errorMessage = message
    }
}

struct TermsOfServiceLink: View {
    @Binding var showDisclaimer: Bool

    var body: some View {
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
    }
}

struct AdminLoginLink: View {
    @Binding var showAdminLogin: Bool
    @Binding var navigateToAdminMenu: Bool

    var body: some View {
        Button(action: {
            showAdminLogin.toggle()
        }) {
            Text("Admin Login")
                .font(.footnote)
                .foregroundColor(.blue)
        }
        .sheet(isPresented: $showAdminLogin) {
            AdminLoginView(isPresented: $showAdminLogin)
        }
    }
}


struct LoginViewLoginView: View {
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
    @State private var selectedTabIndex: Int = 0
    @Binding var isSelected: LoginViewSelection
    @Binding var navigateToAdminMenu: Bool
    @State private var createAccountLinkActive = false
    @State private var isSignInEnabled: Bool = false
    @StateObject private var authViewModel = AuthViewModel.shared
    @Binding var isLoggedIn: Bool
    @State private var persistenceController: PersistenceController
    let profileViewModel: ProfileViewModel


    init(
        islandViewModel: PirateIslandViewModel,
        profileViewModel: ProfileViewModel,
        persistenceController: PersistenceController,
        isSelected: Binding<LoginViewSelection>,
        navigateToAdminMenu: Binding<Bool>,
        isLoggedIn: Binding<Bool>
    ) {
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        self.profileViewModel = profileViewModel
        self.persistenceController = persistenceController
        self._isSelected = isSelected
        self._navigateToAdminMenu = navigateToAdminMenu
        self._isLoggedIn = isLoggedIn
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MFBACKGROUND() // Background view
                
                VStack(spacing: 20) {
                    // Display CreateAccountView when the selected view is 'createAccount'
                    if isSelected == .createAccount {
                        CreateAccountView(
                            islandViewModel: islandViewModel,
                            isUserProfileActive: $isUserProfileActive,
                            persistenceController: persistenceController, // Pass to CreateAccountView
                            selectedTabIndex: $selectedTabIndex
                        )
                    }
                    // Display IslandMenu if authenticated and 'showMainContent' is true
                    else if authenticationState.isAuthenticated && showMainContent {
                        IslandMenu(
                            isLoggedIn: $authenticationState.isLoggedIn,
                            authViewModel: authViewModel,
                            profileViewModel: profileViewModel
                        )
                    }
                    // Display LoginForm when the selected view is 'login'
                    else if isSelected == .login {
                        VStack(spacing: 20) {
                            // NavigationLink to AdminMenu
                            NavigationLink(destination: AdminMenu(), isActive: $navigateToAdminMenu) {
                                EmptyView()
                            }
                           
                            // Login form view
                            LoginFormLoginForm(
                                usernameOrEmail: $usernameOrEmail,
                                password: $password,
                                isSignInEnabled: $isSignInEnabled,
                                errorMessage: $errorMessage,
                                islandViewModel: islandViewModel,
                                showMainContent: $showMainContent,
                                isLoggedIn: $isLoggedIn,
                                navigateToAdminMenu: $navigateToAdminMenu
                            )
                        }
                    }
                }
            }
        }
    }
}




// Preview setup with corrected initializations
struct LoginViewLoginView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let islandViewModel = PirateIslandViewModel(persistenceController: persistenceController)
        let authenticationState = AuthenticationState()
        let profileViewModel = ProfileViewModel(
            viewContext: persistenceController.container.viewContext,
            authViewModel: AuthViewModel.shared
        )
        
        LoginViewLoginView(
            islandViewModel: islandViewModel,
            profileViewModel: profileViewModel,
            persistenceController: persistenceController,
            isSelected: .constant(.login),
            navigateToAdminMenu: .constant(false),
            isLoggedIn: .constant(false)
        )
        .environmentObject(authenticationState)
    }
}
