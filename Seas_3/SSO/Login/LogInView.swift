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

// Login Form View (No changes needed here for NavigationStack removal,
// but review the signIn logic if it's still directly calling Firebase
// instead of AuthViewModel.shared)
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
                        // .environmentObject(authenticationState) // <-- This line should be REMOVED (already removed)
                        .frame(height: 50)
                        .clipped()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                VStack {
                    // These NavigationLinks will now push onto the AppRootView's NavigationStack
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

        let normalizedUsernameOrEmail = usernameOrEmail.lowercased()

        do {
            print("Starting sign-in process for \(normalizedUsernameOrEmail)")

            // Crucially, ensure AuthViewModel.shared.signInUser() is indeed handling Firebase Auth
            // and updating authenticationState
            try await AuthViewModel.shared.signInUser(with: normalizedUsernameOrEmail, password: password)

            DispatchQueue.main.async {
                self.authenticationState.setIsAuthenticated(true)
                self.isLoggedIn = true
                self.showMainContent = true // This will be handled by AppRootView's logic
            }
        } catch {
            print("Error during sign-in: \(error.localizedDescription)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .showToast, object: nil, userInfo: ["message": error.localizedDescription])
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // Remove or internalize these if they are solely for AuthViewModel's use
    // private func signInWithEmail(email: String, password: String) async throws { ... }
    // private func fetchUser(_ usernameOrEmail: String) async throws -> UserInfo { ... }

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
            // Directly embed the content, removing the 'navigationContent' private var
            // and its encapsulating NavigationStack
            VStack(spacing: 20) {
                // Since `MapsToAdminMenu` is a Binding<Bool>, it acts as a destination
                // for NavigationLink. This can be used for programmatic navigation.
                // However, a simple NavigationLink to EmptyView here might be unnecessary
                // if the NavigationStack path in AppRootView is used for routing.
                // I'm going to remove this specific NavigationLink for now,
                // assuming any actual navigation happens via buttons/actions.
                // If you *need* programmatic navigation from LoginView *to* AdminMenu
                // as a specific path value, you'd define a `NavigationLink(value: someEnumValue)`
                // and push that value onto the parent's `navigationPath`.
                // For simplicity, let's assume `AdminLoginView` is the direct destination
                // from a NavigationLink.

                // The original 'navigationLinks' now might be better handled directly
                // or if it was for programmatic navigation, that should be tied
                // to AppRootView's navigationPath.
                // I'm commenting out the `navigationLinks` private var and integrating
                // its logical flow directly or via other means.
                // If `MapsToAdminMenu` was meant to be used for a NavigationLink value,
                // it needs to be an identifiable type that `NavigationStack` can push.
                // Since you have a direct NavigationLink to `AdminLoginView` in LoginForm,
                // this `navigationLinks` in LoginView is likely redundant.

                mainContent // This is the actual content that was inside the removed NavigationStack
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .padding()
            .onChange(of: showMainContent) { newValue in
                isLoggedIn = newValue
            }

            toastContent // This remains as is
        }
        .setupListeners(showToastMessage: $showToastMessage, isToastShown: $isToastShown, isLoggedIn: authenticationState.isAuthenticated)
        .onAppear {
            print("Login screen loaded (LoginView)")
        }
        .onDisappear {
            isToastShown = false
            showToastMessage = ""
            print("Login screen has finished loading (LoginView)")
        }
    }

    // Removed: private var navigationContent: some View { ... }

    private var toastContent: some View {
        Group {
            if isToastShown {
                ToastView(showToast: $isToastShown, message: showToastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
    }

    // Removed: private var navigationLinks: some View { ... }
    // If you need programmatic push to AdminMenu, consider using AppRootView's NavigationPath.

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
            } else if authenticationState.isAuthenticated {
                IslandMenu(
                    // REMOVE: isLoggedIn: $authenticationState.isLoggedIn,
                    // REMOVE: authViewModel: authViewModel,
                    profileViewModel: profileViewModel // KEEP THIS, as it's the only one expected by your init
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
                navigateToCreateAccount = true
            }) {
                Text("Create an Account")
                    .font(.body)
                    .foregroundColor(.blue)
                    .underline()
            }
        }
        .background(
            // This NavigationLink will now push onto the AppRootView's NavigationStack
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

// Modifier for Notification Listeners (You have two, likely keep the one with isLoggedIn and DispatchQueue)
// I'm keeping the one with `isLoggedIn` and `DispatchQueue.main.asyncAfter` as it seems more complete.
/*
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
*/
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
