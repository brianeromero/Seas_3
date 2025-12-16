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


// MARK: - UTILITY ENUMS
public enum LoginViewSelection: Int, CaseIterable { // Made CaseIterable for Picker
    case login = 0
    case createAccount = 1

    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .login
        case 1: self = .createAccount
        default: return nil
        }
    }
}


enum UserFetchError: LocalizedError {
    case userNotFound
    case emailNotFound

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "No user found with that username or email."
        case .emailNotFound:
            return "The email address provided does not exist in our records."
        }
    }
}

enum AppAuthError: LocalizedError {
    case firebaseError(CreateAccountError)
    case userFetchError(UserFetchError)
    case invalidCredentials
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .firebaseError(let error):
            switch error {
            case .emailAlreadyInUse:
                return "This email is already registered."
            case .userNotFound:
                return "No account found with that email."
            case .invalidEmailOrPassword:
                return "Invalid email or password."
            default:
                return "An unknown Firebase error occurred."
            }
        case .userFetchError(let error):
            return error.errorDescription
        case .invalidCredentials:
            return "Invalid username or password."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}


// MARK: - HERO HEADER VIEW
struct HeroHeaderView: View {
    @Binding var selectedLoginTab: LoginViewSelection
    @ObservedObject var islandViewModel: PirateIslandViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            // MARK: - Logo
            VStack(spacing: 8) {
                Image("MF_little_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .offset(y: 50) // moves image down 20 points
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // MARK: - Segmented Control
            Picker("Select View", selection: $selectedLoginTab) {
                ForEach(LoginViewSelection.allCases, id: \.self) { tab in
                    Text(tab == .login ? "Log In" : "Create Account")
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .tint(.white)
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
    }
}


// MARK: - LOGIN FORM
struct LoginForm: View {
    @Binding var usernameOrEmail: String
    @Binding var password: String
    @Binding var isSignInEnabled: Bool
    @Binding var errorMessage: String
    @EnvironmentObject var authenticationState: AuthenticationState
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @Binding var showMainContent: Bool
    @Binding var isLoggedIn: Bool
    @Binding var navigateToAdminMenu: Bool
    @State private var isPasswordVisible = false

    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Username / Email + Password
            VStack(spacing: 15) {
                
                // Username / Email
                VStack(alignment: .leading, spacing: 5) {
                    Text("Username or Email")
                        .foregroundColor(.white)
                        .font(.subheadline)
                    
                    TextField("Email Address", text: $usernameOrEmail)
                        .font(.subheadline)
                        .padding(.vertical, 8)    // reduced height
                        .padding(.horizontal, 12) // balanced sides
                        .frame(height: 44)        // accessibility minimum
                        .background(Color.gray.opacity(0.4))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: usernameOrEmail) { _, newValue in
                            isSignInEnabled = !newValue.isEmpty && !password.isEmpty
                        }
                }
                
                // Password
                VStack(alignment: .leading, spacing: 5) {
                    Text("Password")
                        .foregroundColor(.white)
                        .font(.subheadline)
                    
                    HStack(spacing: 8) {
                        Group {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(Color.gray.opacity(0.4))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .onChange(of: password) { _, newValue in
                            isSignInEnabled = !usernameOrEmail.isEmpty && !newValue.isEmpty
                        }

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            // MARK: - Sign In Button
            Button {
                Task { await signIn() }
            } label: {
                Text("Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44) // same visual rhythm as fields
                    .background(isSignInEnabled ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isSignInEnabled)
            
            // MARK: - OR Separator
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.5))
                Text("OR")
                    .foregroundColor(.gray)
                    .font(.caption)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.vertical, 10)
            
            // MARK: - Social Buttons
            HStack(spacing: 25) {

                GoogleSignInButtonWrapper(
                    onSuccess: {
                        authenticationState.setIsAuthenticated(true)
                        authenticationState.navigateUnrestricted = true
                        isLoggedIn = true
                        showMainContent = true

                        NotificationCenter.default.post(name: .navigateHome, object: nil)
                    },
                    onError: { message in
                        errorMessage = message
                    }
                )
                .frame(width: 50, height: 50)

                AppleSignInButtonView { result in
                    switch result {
                    case .success(_):
                        DispatchQueue.main.async {
                            authenticationState.setIsAuthenticated(true)
                            authenticationState.navigateUnrestricted = true
                            isLoggedIn = true
                            showMainContent = true

                            // 🔑 KEEP APPLE CONSISTENT TOO
                            NotificationCenter.default.post(name: .navigateHome, object: nil)
                        }

                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .frame(width: 50, height: 50)
            }

            
            // MARK: - Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // MARK: - Links
            VStack(spacing: 10) {
                NavigationLink(destination: ApplicationOfServiceView()) {
                    (
                        Text("By continuing, you agree to the ")
                            .foregroundColor(.gray)
                        +
                        Text("Terms of Service/Disclaimer")
                            .foregroundColor(.blue)
                            .underline()
                    )
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                NavigationLink(destination: AdminLoginView(isPresented: .constant(false))) {
                    Text("Admin Login")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Spacer()

        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        // Removed black background so gradient shows through
    }

    private func signIn() async {
        guard !usernameOrEmail.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both username and password."
            return
        }
        
        do {
            try await AuthViewModel.shared.signInUser(
                with: usernameOrEmail.lowercased(),
                password: password
            )
            
            await MainActor.run {
                authenticationState.setIsAuthenticated(true)
                authenticationState.navigateUnrestricted = true   // ✅ REQUIRED
                isLoggedIn = true
                showMainContent = true

                // ✅ THIS IS THE MISSING LINE
                NotificationCenter.default.post(name: .navigateHome, object: nil)
            }

            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

}


enum AccountAlertType {
    case successAccount
    case successAccountAndGym
    case notice

    var title: String {
        switch self {
        case .successAccount, .successAccountAndGym: return "Congratulations!"
        case .notice: return "Notice"
        }
    }

    var defaultMessage: String {
        switch self {
        case .successAccount: return "Account Created Successfully! You will now be navigated back to Main Menu."
        case .successAccountAndGym: return "Account Created Successfully and your gym has been added to the database! You will now be navigated back to Main Menu."
        case .notice: return ""
        }
    }
}

// MARK: - LOGIN VIEW
struct LoginView: View {
    @EnvironmentObject var authenticationState: AuthenticationState
    
    @StateObject private var islandViewModel: PirateIslandViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    
    @Binding var selectedLoginTab: LoginViewSelection
    @Binding var navigateToAdminMenu: Bool
    @Binding var isLoggedIn: Bool
    @Binding var navigationPath: NavigationPath

    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isSignInEnabled = false
    @State private var showMainContent = false
    
    // Local tab used only for toggling Login / CreateAccount screens
    @State private var loginTabSelection: LoginViewSelection = .login
    
    // MARK: - Alerts
    @State private var showAlert = false
    @State private var alertTitle = "Notice"
    @State private var alertMessage = ""
    @State private var currentAlertType: AccountAlertType? = nil

    // MARK: - Initializer
    public init(
        islandViewModel: PirateIslandViewModel,
        profileViewModel: ProfileViewModel,
        isSelected: Binding<LoginViewSelection>,
        navigateToAdminMenu: Binding<Bool>,
        isLoggedIn: Binding<Bool>,
        navigationPath: Binding<NavigationPath>
    ) {
        _selectedLoginTab = isSelected
        _navigateToAdminMenu = navigateToAdminMenu
        _isLoggedIn = isLoggedIn
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        _profileViewModel = StateObject(wrappedValue: profileViewModel)
        _navigationPath = navigationPath
    }
    
    // MARK: - BODY
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.2, blue: 0.25),
                         Color(red: 0.05, green: 0.15, blue: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                /*
                // ----------------------------------------------------
                // MARK: - AUTHENTICATED VIEW (NO AUTO-NAVIGATION)
                // ----------------------------------------------------
                if authenticationState.accountCreatedSuccessfully {
                    VStack {
                        Spacer()
                        Text("from loginview")
                            .foregroundColor(.white)
                            .font(.title)
                        Spacer()
                    }
                }
                */
                
                // Success banner (optional)
                if authenticationState.accountCreatedSuccessfully,
                   let type = currentAlertType {
                    Text(type.defaultMessage)
                        .foregroundColor(.green)
                        .padding()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    // Hide banner
                                    authenticationState.accountCreatedSuccessfully = false
                                    currentAlertType = nil
                                    
                                    // Navigate to IslandMenu2
                                    navigationPath.removeLast(navigationPath.count)
                                    navigationPath.append(AppScreen.islandMenu2)
                                }
                            }
                        }
                }
                
                HeroHeaderView(
                    selectedLoginTab: $loginTabSelection,
                    islandViewModel: islandViewModel
                )
                
                if loginTabSelection == .login {
                    LoginForm(
                        usernameOrEmail: $usernameOrEmail,
                        password: $password,
                        isSignInEnabled: $isSignInEnabled,
                        errorMessage: $errorMessage,
                        islandViewModel: islandViewModel,
                        showMainContent: $showMainContent,
                        isLoggedIn: $isLoggedIn,
                        navigateToAdminMenu: $navigateToAdminMenu
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    CreateAccountView(
                        islandViewModel: islandViewModel,
                        isUserProfileActive: .constant(false),
                        selectedTabIndex: $selectedLoginTab,
                        navigationPath: $navigationPath,
                        persistenceController: PersistenceController.shared,
                        emailManager: UnifiedEmailManager.shared,
                        showAlert: $showAlert,
                        alertTitle: $alertTitle,
                        alertMessage: $alertMessage,
                        currentAlertType: $currentAlertType
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.default, value: loginTabSelection)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    handleAlertDismiss()
                }
            )
        }
    }
    
    // MARK: - ALERT DISMISS HANDLER
    private func handleAlertDismiss() {
        guard let type = currentAlertType else { return }

        switch type {
        case .successAccount, .successAccountAndGym:
            selectedLoginTab = .login
            authenticationState.accountCreatedSuccessfully = false
            currentAlertType = nil
            
            // Navigate to IslandMenu2
            navigationPath.removeLast(navigationPath.count)
            navigationPath.append(AppScreen.islandMenu2)
            
        case .notice:
            break
        }
    }
}


extension View {
    func setupListeners(showToastMessage: Binding<String>, isToastShown: Binding<Bool>, isLoggedIn: Bool = false) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: Notification.Name.showToast)) { notification in
            guard isLoggedIn else { return }
            if let message = notification.userInfo?["message"] as? String {
                showToastMessage.wrappedValue = message
                isToastShown.wrappedValue = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isToastShown.wrappedValue = false
                }
            }
        }
    }
}
