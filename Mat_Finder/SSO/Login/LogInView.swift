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

    var body: some View {
        VStack(spacing: 15) {
            // Logo
            VStack(spacing: 8) {
                Image("MF_little_trans")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text("Mat_Finder")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.top, 50)
            .padding(.bottom, 20)

            // Segmented control
            Picker("", selection: $selectedLoginTab) {
                Text("Log In").tag(LoginViewSelection.login)
                Text("Create Account").tag(LoginViewSelection.createAccount)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .tint(.white)
            .background(Color.clear)
            .controlSize(.large)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.04, green: 0.09, blue: 0.13),
                    Color(red: 0.07, green: 0.15, blue: 0.20)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.top)
        )
    }
}


// MARK: - LOGIN FORM (Revised to match Mockup 2 style)
struct LoginForm: View {
    @Binding var usernameOrEmail: String
    @Binding var password: String
    @Binding var isSignInEnabled: Bool
    @Binding var errorMessage: String
    @EnvironmentObject var authenticationState: AuthenticationState
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @Binding var showMainContent: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isPasswordVisible = false
    @Binding var isLoggedIn: Bool
    @Binding var navigateToAdminMenu: Bool
    @State private var showToastMessage: String = ""

    var body: some View {
        VStack(spacing: 25) {
            
            // MARK: - Username/Email Field
            VStack(alignment: .leading, spacing: 5) {
                Text("Username or Email")
                    .foregroundColor(.white) // Text label color
                    .font(.body)
                
                TextField("Email Address", text: $usernameOrEmail) // Changed placeholder text to match mockup
                    .padding()
                    .background(Color.gray.opacity(0.4)) // Darker gray for contrast on dark background
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.7), lineWidth: 1) // Subtle border
                    )
                    .onChange(of: usernameOrEmail) { _, newValue in
                        isSignInEnabled = !newValue.isEmpty && !password.isEmpty
                    }
                    .accessibilityLabel("Username or Email input")
            }
            
            // MARK: - Social Login Icons (Moved above password field as per Mockup 2)
            HStack(spacing: 25) {
                GoogleSignInButtonWrapper { message in
                    self.errorMessage = message
                }
                .frame(width: 50, height: 50)

                AppleSignInButtonView(
                    onRequest: { /* Configure scopes if needed */ },
                    onCompletion: { result in
                        // ... existing logic ...
                    }
                )
                .frame(width: 50, height: 50)
            }
            
            Text("OR")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.vertical, -5)
            
            // MARK: - Password Field
            VStack(alignment: .leading, spacing: 5) {
                Text("Password")
                    .foregroundColor(.white) // Text label color
                    .font(.body)
                
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
                    .foregroundColor(.white)
                    .disableAutocorrection(true)
                    .textContentType(.password)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.7), lineWidth: 1)
                    )
                    
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                            .padding(.trailing, 5)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .onChange(of: password) { _, newValue in
                    isSignInEnabled = !usernameOrEmail.isEmpty && !newValue.isEmpty
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
            
            // MARK: - Footer Links and Error
            VStack(spacing: 10) {
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .font(.caption)
                }

                // Terms of Service Link
                NavigationLink(destination: ApplicationOfServiceView()) {
                    Text("By continuing, you agree to the updated Terms of Service/Disclaimer")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                }

                // Admin Login Link
                NavigationLink(destination: AdminLoginView(isPresented: .constant(false))) {
                    Text("Admin Login")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .underline()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20) // Use horizontal padding for a cleaner look
        .padding(.top, 30) // Push content down slightly from the header
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.bottom))
        .foregroundColor(.white) // Default text color for the form
    }

    // MARK: - Sign In Logic (no changes needed)
    private func signIn() async {
        guard !usernameOrEmail.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both username and password."
            return
        }

        let normalizedUsernameOrEmail = usernameOrEmail.lowercased()

        do {
            try await AuthViewModel.shared.signInUser(
                with: normalizedUsernameOrEmail,
                password: password
            )

            DispatchQueue.main.async {
                authenticationState.setIsAuthenticated(true)
                isLoggedIn = true
                showMainContent = true
            }

        } catch let error as AppAuthError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleAppAuthError(_ error: AppAuthError) {
        NotificationCenter.default.post(
            name: .showToast,
            object: nil,
            userInfo: ["message": error.localizedDescription]
        )
        errorMessage = error.localizedDescription
    }

    private let userFetcher = UserFetcher()

    private func fetchUser(_ usernameOrEmail: String) async throws -> UserInfo {
        print("Fetching user with identifier: \(usernameOrEmail)")
        return try await userFetcher.fetchUser(usernameOrEmail: usernameOrEmail, context: viewContext)
    }

    private func showAlert(with message: String) {
        print("Showing alert with message: \(message)")
        errorMessage = message
    }
}


// MARK: - LOGIN VIEW
public struct LoginView: View {
    @Binding var navigationPath: NavigationPath

    @EnvironmentObject var authenticationState: AuthenticationState
    @Environment(\.managedObjectContext) private var viewContext

    @State private var showMainContent: Bool = false
    @State private var errorMessage: String = ""
    @State private var usernameOrEmail: String = ""
    @State private var password: String = ""
    @State private var showAlert = false
    @State private var showDisclaimer = false
    @State private var showAdminLogin = false
    @StateObject private var islandViewModel: PirateIslandViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var isUserProfileActive: Bool = false
    @State private var selectedTabIndex: Int = 0
    @State private var selectedLoginTab: LoginViewSelection
    @Binding private var navigateToAdminMenu: Bool
    @Binding private var isLoggedIn: Bool
    @State private var isSignInEnabled: Bool = false
    @State private var showToastMessage: String = ""
    @State private var isToastShown: Bool = false

    public init(
        islandViewModel: PirateIslandViewModel,
        profileViewModel: ProfileViewModel,
        isSelected: Binding<LoginViewSelection>,
        navigateToAdminMenu: Binding<Bool>,
        isLoggedIn: Binding<Bool>,
        navigationPath: Binding<NavigationPath>
    ) {
        _selectedLoginTab = State(initialValue: isSelected.wrappedValue)
        _navigateToAdminMenu = navigateToAdminMenu
        _isLoggedIn = isLoggedIn
        _navigationPath = navigationPath
        _islandViewModel = StateObject(wrappedValue: islandViewModel)
        _profileViewModel = StateObject(wrappedValue: profileViewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            mainContent
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onChange(of: showMainContent) {
            isLoggedIn = showMainContent
        }
        .showToast(
            isPresenting: $isToastShown,
            message: showToastMessage,
            type: .success
        )
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.showToast)) { notification in
            if let message = notification.userInfo?["message"] as? String {
                showToastMessage = message
                isToastShown = true
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            
            if authenticationState.isAuthenticated {
                IslandMenu2(
                    profileViewModel: profileViewModel,
                    navigationPath: $navigationPath
                )
            } else {
                VStack(spacing: 0) {
                    
                    // 1. Hero Header (Logo + Segmented Control)
                    HeroHeaderView(
                        selectedLoginTab: $selectedLoginTab,
                        islandViewModel: islandViewModel
                    )
                    
                    // 2. Main Content (Login Form or Create Account Form)
                    Group {
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
                            
                        } else { // selectedLoginTab == .createAccount
                            CreateAccountView(
                                islandViewModel: islandViewModel,
                                isUserProfileActive: $isUserProfileActive,
                                persistenceController: PersistenceController.shared,
                                selectedTabIndex: $selectedTabIndex,
                                emailManager: UnifiedEmailManager.shared
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.default, value: selectedLoginTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.black.edgesIgnoringSafeArea(.all))
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

struct HeroHeaderView_Previews: PreviewProvider {
    @State static var selectedLoginTab: LoginViewSelection = .login
    static var islandViewModel = PirateIslandViewModel(
        persistenceController: PersistenceController.preview
    )

    static var previews: some View {
        HStack(spacing: 0) {
            // Light mode
            HeroHeaderView(
                selectedLoginTab: $selectedLoginTab,
                islandViewModel: islandViewModel
            )
            .environment(\.colorScheme, .light)
            .previewLayout(.sizeThatFits)
            .frame(width: 220, height: 260)
            .background(Color.white)
            .cornerRadius(12)
            .padding()

            // Dark mode
            HeroHeaderView(
                selectedLoginTab: $selectedLoginTab,
                islandViewModel: islandViewModel
            )
            .environment(\.colorScheme, .dark)
            .previewLayout(.sizeThatFits)
            .frame(width: 220, height: 260)
            .background(Color.black)
            .cornerRadius(12)
            .padding()
        }
        .previewDisplayName("HeroHeaderView – Light vs Dark")
    }
}
