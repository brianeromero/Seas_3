import SwiftUI
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignIn

// Custom URLHandler view
struct URLHandler: View {
    var body: some View {
        EmptyView()
            .onOpenURL { url in
                print("🔗 Received URL: \(url.absoluteString) at \(Date())")

                if url.absoluteString.contains("fb") {
                    print("✅ Facebook URL handled: \(url)")
                } else if GIDSignIn.sharedInstance.handle(url) {
                    print("✅ Google URL handled successfully: \(url)")
                } else {
                    print("❌ URL not handled: \(url)")
                }
            }
    }
}

@main
struct Seas_3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var authenticationState = AuthenticationState(hashPassword: HashPassword())
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject var profileViewModel = ProfileViewModel(
        viewContext: PersistenceController.shared.container.viewContext,
        authViewModel: AuthViewModel.shared
    )
    @StateObject var authViewModel = AuthViewModel.shared

    @State private var selectedTabIndex: LoginViewSelection = .login

    var body: some Scene {
        WindowGroup {
            ZStack {
                if appState.showWelcomeScreen {
                    PirateIslandView(appState: appState)
                        .transition(.opacity)
                        .onAppear {
                            print("👀 PirateIslandView appeared at \(Date())")
                            print("📊 Current State: showWelcomeScreen = \(appState.showWelcomeScreen)")

                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                print("⏰ Dismissing PirateIslandView at \(Date())")
                                withAnimation(.easeInOut(duration: 1)) {
                                    print("🏁 Setting appState.showWelcomeScreen = false")
                                    appState.showWelcomeScreen = false
                                }
                            }
                            setupGlobalErrorHandler()
                        }
                        .onDisappear {
                            print("👋 PirateIslandView disappeared at \(Date())")
                        }

                } else if authenticationState.isAuthenticated && authenticationState.navigateToAdminMenu {
                    AdminMenu()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(authenticationState)
                        .environmentObject(appState)
                        .environmentObject(profileViewModel)
                        .onAppear {
                            print("✅ AdminMenu appeared at \(Date())")
                            print("📊 Auth State: isAuthenticated = \(authenticationState.isAuthenticated), navigateToAdminMenu = \(authenticationState.navigateToAdminMenu)")
                            setupGlobalErrorHandler()
                        }

                } else if authenticationState.isAuthenticated && authenticationState.isLoggedIn {
                    IslandMenu(
                        isLoggedIn: $authenticationState.isLoggedIn,
                        authViewModel: authViewModel,
                        profileViewModel: profileViewModel
                    )
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authenticationState)
                    .environmentObject(appState)
                    .onAppear {
                        print("✅ IslandMenu appeared at \(Date())")
                        print("📊 Auth State: isAuthenticated = \(authenticationState.isAuthenticated), isLoggedIn = \(authenticationState.isLoggedIn)")

                        let sceneLoader = SceneLoader()
                        sceneLoader.loadScene()
                        setupGlobalErrorHandler()
                    }

                } else {
                    LoginView(
                        islandViewModel: PirateIslandViewModel(persistenceController: persistenceController),
                        profileViewModel: profileViewModel,
                        isSelected: $selectedTabIndex,
                        navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                        isLoggedIn: $authenticationState.isLoggedIn
                    )
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authenticationState)
                    .onAppear {
                        print("✅ LoginView appeared at \(Date())")
                        print("📊 Auth State: isAuthenticated = \(authenticationState.isAuthenticated), isLoggedIn = \(authenticationState.isLoggedIn)")
                        setupGlobalErrorHandler()
                    }
                }
            }
            .background(URLHandler())  // Add URL handler globally here
        }
    }

    private func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler { exception in
            NSLog("🔥 Uncaught Exception: %@", exception)
            if let reason = exception.reason {
                NSLog("🛑 Reason: %@", reason)
            }
        }
    }
}

// Add this extension for PersistenceController in Environment
struct PersistenceControllerKey: EnvironmentKey {
    static var defaultValue: PersistenceController { PersistenceController.shared }
}

extension EnvironmentValues {
    var persistenceController: PersistenceController {
        get { self[PersistenceControllerKey.self] }
        set { self[PersistenceControllerKey.self] = newValue }
    }
}
