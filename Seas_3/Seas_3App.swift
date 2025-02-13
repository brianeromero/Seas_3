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
                if url.absoluteString.contains("fb") {
                    print("Facebook URL handled: \(url)")
                } else if GIDSignIn.sharedInstance.handle(url) {
                    print("Google URL handled successfully: \(url)")
                } else {
                    print("URL not handled: \(url)")
                }
            }
    }
}

@main
struct Seas_3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var authenticationState = AuthenticationState()
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject var profileViewModel = ProfileViewModel(
        viewContext: PersistenceController.shared.container.viewContext,
        authViewModel: AuthViewModel.shared
    )
    @StateObject var authViewModel = AuthViewModel.shared

    @State private var selectedTabIndex: LoginViewSelection = .login

    var body: some Scene {
        WindowGroup {
            URLHandler()  // Handle URLs for Google/Facebook sign-ins
            
            if appState.showWelcomeScreen {
                PirateIslandView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation {
                                appState.showWelcomeScreen = false
                            }
                        }
                        setupGlobalErrorHandler()
                    }
            } else if authenticationState.isAuthenticated && authenticationState.navigateToAdminMenu {
                AdminMenu()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authenticationState)
                    .environmentObject(appState)
                    .environmentObject(profileViewModel)
                    .onAppear {
                        setupGlobalErrorHandler()
                    }
            } else if authenticationState.isAuthenticated && authenticationState.isLoggedIn {
                IslandMenu(isLoggedIn: $authenticationState.isLoggedIn, authViewModel: authViewModel)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authenticationState)
                    .environmentObject(appState)
                    .environmentObject(profileViewModel)
                    .onAppear {
                        let sceneLoader = SceneLoader()
                        sceneLoader.loadScene()
                        setupGlobalErrorHandler()
                    }
            } else {
                LoginView(
                    islandViewModel: PirateIslandViewModel(persistenceController: persistenceController),
                    isSelected: $selectedTabIndex,
                    navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                    isLoggedIn: $authenticationState.isLoggedIn
                )
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authenticationState)
                .onAppear {
                    setupGlobalErrorHandler()
                }
            }
        }
        .environment(\.persistenceController, persistenceController)
        .environmentObject(profileViewModel)
    }

    private func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler { exception in
            NSLog("Uncaught Exception: %@", exception)
            if let reason = exception.reason,
               reason.contains("has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API") {
                NSLog("Caught NaN error: %@", reason)
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
