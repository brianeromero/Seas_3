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
        case 0:
            self = .login
        case 1:
            self = .createAccount
        default:
            return nil
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
    
    private let heroBackgroundColor = Color(red: 0.1, green: 0.2, blue: 0.25)
    
    var body: some View {
        VStack(spacing: 15) {
            // MARK: - Logo
            VStack(spacing: 8) {
                Image("MF_little_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                
                Text("Mat_Finder")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .padding(.top, 40)
            .padding(.bottom, 20)
            
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
        .background(heroBackgroundColor.edgesIgnoringSafeArea(.top))
        .frame(maxWidth: .infinity)
    }
}


// MARK: - LOGIN FORM (Organized to Match Mockup)
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
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isPasswordVisible = false

    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Username / Email + Password
            VStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Username or Email")
                        .foregroundColor(.white)
                    TextField("Email Address", text: $usernameOrEmail)
                        .padding()
                        .background(Color.gray.opacity(0.4))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: usernameOrEmail) { _, newValue in
                            isSignInEnabled = !newValue.isEmpty && !password.isEmpty
                        }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("Password")
                        .foregroundColor(.white)
                    
                    HStack {
                        Group {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .padding()
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
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isSignInEnabled ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
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
                GoogleSignInButtonWrapper { message in
                    self.errorMessage = message
                }
                .frame(width: 50, height: 50)
                
                AppleSignInButtonView(
                    onRequest: { },
                    onCompletion: { _ in }
                )
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
                    Text("By continuing, you agree to the Terms of Service/Disclaimer")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                
                NavigationLink(destination: AdminLoginView(isPresented: .constant(false))) {
                    Text("Admin Login")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .background(Color.black.edgesIgnoringSafeArea(.bottom))
    }

    // MARK: - Sign In Function
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
            DispatchQueue.main.async {
                authenticationState.setIsAuthenticated(true)
                isLoggedIn = true
                showMainContent = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


// MARK: - LOGIN VIEW
struct LoginView: View {
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var viewContext
    
    // Keep these as StateObjects
    @StateObject private var islandViewModel: PirateIslandViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    
    // Form state
    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isSignInEnabled = false
    @State private var showMainContent = false
    
    // Bindings
    @Binding var selectedLoginTab: LoginViewSelection
    @Binding var navigateToAdminMenu: Bool
    @Binding var isLoggedIn: Bool

    // MARK: - Init
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
        _navigationPath = navigationPath
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        _profileViewModel = StateObject(wrappedValue: profileViewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if authenticationState.isAuthenticated {
                IslandMenu2(
                    profileViewModel: profileViewModel, // Pass the StateObject
                    navigationPath: $navigationPath
                )
            } else {
                VStack(spacing: 0) {
                    HeroHeaderView(
                        selectedLoginTab: $selectedLoginTab,
                        islandViewModel: islandViewModel
                    )
                    
                    if selectedLoginTab == .login {
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
                            persistenceController: PersistenceController.shared,
                            selectedTabIndex: .constant(LoginViewSelection.createAccount.rawValue),
                            emailManager: UnifiedEmailManager.shared
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.default, value: selectedLoginTab)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
    }
}




extension View {
    func setupListeners(showToastMessage: Binding<String>, isToastShown: Binding<Bool>, isLoggedIn: Bool = false) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: Notification.Name.showToast)) { notification in
            guard isLoggedIn else { return } // Only show toast if user is logged in (optional logic)
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
