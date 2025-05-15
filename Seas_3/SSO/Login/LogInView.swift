import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreData
import SwiftUI
import GoogleSignInSwift
import FBSDKLoginKit
import Security
import CryptoSwift
import Combine
import os


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

enum UserFetchError: Error {
    case userNotFound
    case emailNotFound
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
    @State private var showToastMessage: String = ""

    var body: some View {
        VStack(spacing: 10) {
            Image("MF_little_trans")
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .padding(.bottom, -40)

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
                            .accessibilityLabel("Password field")
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disableAutocorrection(true)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disableAutocorrection(true)
                            .textContentType(.password)
                    }

                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .onChange(of: password) { newValue in
                    isSignInEnabled = !usernameOrEmail.isEmpty && !newValue.isEmpty
                }
            }
            .padding(.top, -20)
            .frame(maxWidth: .infinity, alignment: .leading)

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

                VStack {
                    HStack {
                        GoogleSignInButtonWrapper(
                            handleError: { message in
                                self.errorMessage = message
                            }
                        )
                        .environmentObject(authenticationState)

                        .frame(height: 50)
                        .clipped()
/*
                        FacebookSignInButtonWrapper(
                            authenticationState: _authenticationState,
                            handleError: { message in
                                self.errorMessage = message
                            }
                        )
                        .frame(height: 50)
                        .clipped()
 
 */
                    }

                }
                .frame(maxHeight: .infinity, alignment: .center)


                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                VStack {
                    NavigationLink(destination: ApplicationOfServiceView()) {
                        Text("By continuing, you agree to the updated Terms of Service/Disclaimer")
                            .font(.footnote)
                            .lineLimit(nil)
                            .multilineTextAlignment(.center)
                            .padding()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, -10)

                    NavigationLink(destination: AdminLoginView(isPresented: .constant(false))) {
                        Text("Admin Login")
                            .font(.footnote)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
            }
            .onAppear {
                print("Login form loaded (LoginForm)")
            }
            .onDisappear {
                print("Login form has finished loading LOGIN FORM")
            }
        }
    }

    // MARK: - Sign In Logic
    private func signIn() async {
        guard !usernameOrEmail.isEmpty && !password.isEmpty else {
            showAlert(with: "Please enter both username and password.")
            return
        }

        let normalizedUsernameOrEmail = usernameOrEmail.lowercased() // Normalize the email to lowercase

        do {
            print("Starting sign-in process for \(normalizedUsernameOrEmail)") // Logging the start of the process
            
            if ValidationUtility.validateEmail(normalizedUsernameOrEmail) != nil {
                print("Email validation passed. Attempting direct email login.") // Logging email login attempt
                // ✅ Direct email login via Firebase
                try await signInWithEmail(email: normalizedUsernameOrEmail, password: password)
            } else {
                print("Email validation failed. Checking Core Data for username.") // Logging when checking Core Data for username
                
                // 🔍 First, try looking up username in Core Data
                do {
                    let user = try await fetchUser(normalizedUsernameOrEmail)
                    print("User found in Core Data: \(user.email)") // Logging user found in Core Data
                    try await signInWithEmail(email: user.email, password: password)
                } catch {
                    print("Username not found in Core Data, checking Firestore...") // Logging when checking Firestore

                    // 🔍 Try Firestore as a last resort
                    do {
                        let user = try await fetchUser(normalizedUsernameOrEmail)
                        print("User found in Firestore: \(user.email)") // Logging user found in Firestore
                        try await signInWithEmail(email: user.email, password: password)
                    } catch {
                        print("Username or email not found in both Core Data and Firestore.") // Logging failed sign-in attempt
                        showAlert(with: "Error logging in. Check Email and Password.")
                    }
                }
            }
        } catch let error {
            print("Error during sign-in: \(error.localizedDescription)") // Logging error during sign-in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .showToast, object: nil, userInfo: ["message": error.localizedDescription])
                self.errorMessage = error.localizedDescription
            }
        }
    }


    private func signInWithEmail(email: String, password: String) async throws {
        print("Attempting to sign in with email: \(email)") // Logging email sign-in attempt
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            print("Successfully signed in with email: \(email)") // Logging success

            DispatchQueue.main.async {
                self.authenticationState.isAuthenticated = true
                self.isLoggedIn = true
                showMainContent = true
            }
        } catch let error {
            print("Error signing in with email: \(email) - \(error.localizedDescription)") // Logging error during email sign-in
            showAlert(with: error.localizedDescription)
            throw error
        }
    }

    private let userFetcher = UserFetcher()
    
    private func fetchUser(_ usernameOrEmail: String) async throws -> UserInfo {
        print("Fetching user with identifier: \(usernameOrEmail)") // Logging the fetch attempt
        // Pass the viewContext (Core Data context) to UserFetcher
        return try await userFetcher.fetchUser(usernameOrEmail: usernameOrEmail, context: viewContext)
    }

    private func showAlert(with message: String) {
        print("Showing alert with message: \(message)") // Logging when showing an alert
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
    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false
    @State private var navigateToCreateAccount = false
    @StateObject private var profileViewModel: ProfileViewModel



    public init(
        islandViewModel: PirateIslandViewModel,
        profileViewModel: ProfileViewModel,
        isSelected: Binding<LoginViewSelection>,
        navigateToAdminMenu: Binding<Bool>,
        isLoggedIn: Binding<Bool>
    ) {
        _isSelected = isSelected
        _navigateToAdminMenu = navigateToAdminMenu
        _isLoggedIn = isLoggedIn
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        _profileViewModel = StateObject(wrappedValue: profileViewModel)
    }

    public var body: some View {
        ZStack {
            navigationContent
            toastContent
        }
        .setupListeners(showToastMessage: $showToastMessage, isToastShown: $isToastShown)
        .onAppear {
            print("Login screen loaded (LoginView)")
        }
        .onDisappear {
            isToastShown = false
            showToastMessage = ""
            print("Login screen has finished loading (LoginView)")
        }
    }

    private var navigationContent: some View {
        NavigationStack {
            VStack(spacing: 20) {
                navigationLinks
                mainContent
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

    private var toastContent: some View {
        Group {
            if isToastShown {
                ToastView(showToast: $isToastShown, message: showToastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    private var navigationLinks: some View {
        NavigationLink(value: navigateToAdminMenu) {
            EmptyView()
        }
    }

    private var mainContent: some View {
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
                    isLoggedIn: $authenticationState.isLoggedIn,
                    authViewModel: authViewModel,
                    profileViewModel: profileViewModel
                )
            } else if isSelected == .login {
                VStack(spacing: 20) {
                    loginOrCreateAccount
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
                EmptyView()
            }
        }
    }

    private var loginOrCreateAccount: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Log In OR")
            Button(action: {
                print("GO TO Create Account link tapped")
                os_log("Create Account link tapped", log: OSLog.default, type: .info)
                navigateToCreateAccount = true
            }) {
                Text("Create an Account")
                    .font(.body)
                    .foregroundColor(.blue)
                    .underline()
            }
        }
        .background(
            NavigationLink(destination: CreateAccountView(
                islandViewModel: islandViewModel,
                isUserProfileActive: $isUserProfileActive,
                persistenceController: PersistenceController.shared,
                selectedTabIndex: $selectedTabIndex,
                emailManager: UnifiedEmailManager.shared
            ), isActive: $navigateToCreateAccount) {
                EmptyView()
            }
        )
    }
}

// Extension for Notification Name
extension Notification.Name {
    static let showToast = Notification.Name("ShowToast")
}

// Modifier for Notification Listeners
extension View {
    func setupListeners(showToastMessage: Binding<String>, isToastShown: Binding<Bool>) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .showToast)) { notification in
            print("ShowToast notification triggered.")
            if let message = notification.userInfo?["message"] as? String {
                print("Toast requested with message: \(message)")
                showToastMessage.wrappedValue = message
                isToastShown.wrappedValue = true
            } else {
                print("No message found in notification. Skipping toast.")
            }
        }
    }
}

// Preview with mock data
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(
            islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
            profileViewModel: ProfileViewModel(
                viewContext: PersistenceController.shared.container.viewContext,
                authViewModel: AuthViewModel.shared
            ),
            isSelected: .constant(.login),
            navigateToAdminMenu: .constant(false),
            isLoggedIn: .constant(false)
        )
        .environmentObject(AuthenticationState(hashPassword: HashPassword()))
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
