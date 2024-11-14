import Foundation
import FirebaseAuth
import CoreData
import SwiftUI
import GoogleSignIn
import FBSDKLoginKit
import Security
import CryptoSwift

public enum LoginViewSelection: Int {
    case login = 0
    case createAccount = 1
    
    public init?(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .login
        case 1:
            self = .createAccount
        default:
            return nil
        }
    }
}

// Login Form View
struct LoginForm: View {
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

    var body: some View {
        VStack(spacing: 10) {
            Image("MF_little_trans")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .padding(.bottom, -40) // Reduce bottom padding
            
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
            .padding(.top, -20) // Reduce top padding

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
                        googleClientID: AppConfig.shared.googleClientID
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

                NavigationLink(destination: ApplicationOfServiceView()) {
                    Text("By continuing, you agree to the updated Terms of Service/Disclaimer")
                        .font(.footnote)
                        .lineLimit(nil) // or .lineLimit(2) for 2 lines, etc.
                        .multilineTextAlignment(.center)
                        .padding()
                        .fixedSize(horizontal: false, vertical: true) // Allow wrapping
                }
                .padding(.top, -10) // Reduce top padding
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
            // Ensure that fetchUser() is a throwing function
            if ValidationUtility.validateEmail(usernameOrEmail) != nil {
                let user = try fetchUser(usernameOrEmail)  // This should now throw if it fails
                let email = user.email
                try await signInWithEmail(email: email, password: password)
            } else {
                // Handle username login
                try await authViewModel.signInUser(with: usernameOrEmail, password: password)
            }
        } catch let error {
            showAlert(with: error.localizedDescription)
        }
    }


    // Example of signInWithEmail for simplification
    private func signInWithEmail(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            DispatchQueue.main.async {
                self.authenticationState.isAuthenticated = true
                self.isLoggedIn = true
                showMainContent = true
            }
        } catch let error {
            showAlert(with: error.localizedDescription)
            throw error // Rethrow the error if needed
        }
    }

    // MARK: - Fetch User
    private func fetchUser(_ usernameOrEmail: String) throws -> UserInfo {
        let request = NSFetchRequest<UserInfo>(entityName: "UserInfo")
        request.predicate = NSPredicate(format: "userName == %@ OR email == %@", usernameOrEmail, usernameOrEmail)

        let results = try viewContext.fetch(request)  // This is the throwing function
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

public struct LoginView: View {
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
    @Binding private var isSelected: LoginViewSelection
    @Binding private var navigateToAdminMenu: Bool
    @State private var createAccountLinkActive = false
    @State private var isSignInEnabled: Bool = false
    @StateObject private var authViewModel = AuthViewModel.shared
    @Binding private var isLoggedIn: Bool

    public init(
        islandViewModel: PirateIslandViewModel,
        isSelected: Binding<LoginViewSelection>,
        navigateToAdminMenu: Binding<Bool>,
        isLoggedIn: Binding<Bool>
    ) {
        _isSelected = isSelected
        _navigateToAdminMenu = navigateToAdminMenu
        _isLoggedIn = isLoggedIn
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Admin Menu Navigation
                NavigationLink(destination: AdminMenu(), isActive: $navigateToAdminMenu) {
                    EmptyView()
                }

                // Conditional Content Based on Selection
                VStack {
                    if isSelected == .createAccount {
                        CreateAccountView(
                            islandViewModel: islandViewModel,
                            isUserProfileActive: $isUserProfileActive,
                            persistenceController: PersistenceController.shared,
                            selectedTabIndex: $selectedTabIndex,
                            emailManager: UnifiedEmailManager.shared
                        )
                    } else if authenticationState.isAuthenticated && showMainContent {
                        IslandMenu(
                            isLoggedIn: $authenticationState.isLoggedIn
                        )
                    } else if isSelected == .login {
                        VStack(spacing: 20) {
                            HStack(alignment: .center, spacing: 10) {
                                Text("Log In OR")
                                
                                // Create Account Navigation Link
                                NavigationLink(destination: CreateAccountView(
                                    islandViewModel: islandViewModel,
                                    isUserProfileActive: $isUserProfileActive,
                                    persistenceController: PersistenceController.shared,
                                    selectedTabIndex: $selectedTabIndex,
                                    emailManager: UnifiedEmailManager.shared
                                )) {
                                    Text("Create an Account")
                                        .font(.body)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                            }
                            
                            // Login Form
                            LoginForm(
                                usernameOrEmail: $usernameOrEmail,
                                password: $password,
                                isSignInEnabled: $isSignInEnabled,
                                errorMessage: $errorMessage,
                                authenticationState: _authenticationState,
                                islandViewModel: islandViewModel,
                                showMainContent: $showMainContent,
                                isLoggedIn: $isLoggedIn,
                                navigateToAdminMenu: $navigateToAdminMenu
                            )
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
            .onChange(of: showMainContent) { newValue in
                isLoggedIn = newValue
            }
        }
    }
}




// Preview with mock data
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginForm(
            usernameOrEmail: .constant("test@example.com"),
            password: .constant("password123"),
            isSignInEnabled: .constant(true),
            errorMessage: .constant(""),
            islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
            showMainContent: .constant(false),
            isLoggedIn: .constant(false),
            navigateToAdminMenu: .constant(false)
        )
        .environmentObject(AuthenticationState())
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
