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
public enum LoginViewSelection: Int, CaseIterable {
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
        case .successAccount:
            return "Account Created Successfully! You will now be navigated back to Main Menu."
        case .successAccountAndGym:
            return "Account Created Successfully and your gym has been added to the database! You will now be navigated back to Main Menu."
        case .notice:
            return ""
        }
    }
}

// MARK: - LOGIN FORM
struct LoginForm: View {
    @Binding var usernameOrEmail: String
    @Binding var password: String
    @Binding var isSignInEnabled: Bool
    @Binding var errorMessage: String

    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authenticationState: AuthenticationState

    @State private var isPasswordVisible = false

    var body: some View {
        VStack(spacing: 12) {
            credentialFields

            signInButton

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12))
        )
    }

    private var credentialFields: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Username or Email")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                TextField("Email Address", text: $usernameOrEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.next)
                    .onChange(of: usernameOrEmail) { _, _ in updateSignInState() }
                    .modifier(AuthTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                HStack {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                            .submitLabel(.go)
                            .onChange(of: password) { _, _ in updateSignInState() }
                    } else {
                        SecureField("Password", text: $password)
                            .submitLabel(.go)
                            .onChange(of: password) { _, _ in updateSignInState() }
                    }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .modifier(AuthTextFieldStyle())
            }
        }
    }

    private var signInButton: some View {
        Button {
            Task { await signIn() }
        } label: {
            Text("Sign In")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSignInEnabled ? Color.blue : Color.gray.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(color: Color.blue.opacity(0.4), radius: 6, x: 0, y: 3)
        }
        .disabled(!isSignInEnabled)
    }

    private func updateSignInState() {
        isSignInEnabled =
            !usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.isEmpty
    }

    private func signIn() async {
        guard isSignInEnabled else { return }

        do {
            try await AuthViewModel.shared.signInUser(
                with: usernameOrEmail.lowercased(),
                password: password
            )
            await handlePostLogin()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handlePostLogin() async {
        let user = await AuthViewModel.shared.getCurrentUser()

        await MainActor.run {
            authenticationState.setIsAuthenticated(true)
            authenticationState.navigateUnrestricted = true
        }

        guard let userID = user?.userID else { return }

        await profileViewModel.loadProfile(for: userID)
        await MainActor.run {
            NotificationCenter.default.post(name: .navigateHome, object: nil)
        }
    }
}

// MARK: - LOGIN VIEW
struct LoginView: View {
    @EnvironmentObject var authenticationState: AuthenticationState

    @StateObject private var islandViewModel =
        PirateIslandViewModel(persistenceController: .shared)
    @StateObject private var profileViewModel = ProfileViewModel()

    @Binding var isLoggedIn: Bool
    @Binding var navigationPath: NavigationPath

    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isSignInEnabled = false
    @State private var showCreateAccount = false
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var currentAlertType: AccountAlertType?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.2, blue: 0.25),
                         Color(red: 0.05, green: 0.15, blue: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {

                    Image("MFINDER_circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150)
                        .offset(y: -50)

                    Text("Log In to Mat_Finder")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 4)
                    
                    // --- Credential Login Card ---
                    LoginForm(
                        usernameOrEmail: $usernameOrEmail,
                        password: $password,
                        isSignInEnabled: $isSignInEnabled,
                        errorMessage: $errorMessage,
                        islandViewModel: islandViewModel,
                        profileViewModel: profileViewModel
                    )

                    HStack(spacing: 28) {
                        GoogleSignInButtonWrapper(
                            onSuccess: { Task { await handlePostLogin() } },
                            onError: { errorMessage = $0 }
                        )
                        .frame(width: 50, height: 50)

                        AppleSignInButtonView { result in
                            switch result {
                            case .success:
                                Task { await handlePostLogin() }
                            case .failure(let error):
                                errorMessage = error.localizedDescription
                            }
                        }
                        .frame(width: 50, height: 50)
                    }
                    
                    OrDivider()

                    // --- Create Account Button ---
                    Button("Create an Account") {
                        showCreateAccount = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 1.5)
                    )
                    .foregroundColor(.blue)

                    // --- Links ---
                    VStack(spacing: 8) {
                        NavigationLink(destination: ApplicationOfServiceView()) {
                            Text("Terms of Service / Disclaimer")
                                .font(.footnote)
                                .foregroundColor(.blue)
                                .underline()
                        }

                        NavigationLink(destination: AdminLoginView(isPresented: .constant(false))) {
                            Text("Admin Login")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $showCreateAccount) {
            NavigationStack {
                CreateAccountView(
                    islandViewModel: islandViewModel,
                    isUserProfileActive: .constant(false),
                    selectedTabIndex: .constant(.login),
                    navigationPath: $navigationPath,
                    emailManager: UnifiedEmailManager.shared,
                    showAlert: $showAlert,
                    alertTitle: $alertTitle,
                    alertMessage: $alertMessage,
                    currentAlertType: $currentAlertType,
                    showCreateAccount: $showCreateAccount
                )
            }
        }
        // 🔹 React to account creation (iOS 17+)
        .onChange(of: authenticationState.accountCreatedSuccessfully) { oldValue, newValue in
            guard newValue else { return }

            authenticationState.setIsAuthenticated(true)
            authenticationState.navigateUnrestricted = true
            isLoggedIn = true

            // reset the flag
            authenticationState.accountCreatedSuccessfully = false
        }

    }

    private func handlePostLogin() async {
        let user = await AuthViewModel.shared.getCurrentUser()

        await MainActor.run {
            authenticationState.setIsAuthenticated(true)
            authenticationState.navigateUnrestricted = true
            isLoggedIn = true
        }

        guard let userID = user?.userID else { return }

        await profileViewModel.loadProfile(for: userID)
        await MainActor.run {
            NotificationCenter.default.post(name: .navigateHome, object: nil)
        }
    }
}

// MARK: - TEXTFIELD STYLE
struct AuthTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .foregroundColor(.white)
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
