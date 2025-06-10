import SwiftUI
import Foundation // Make sure Foundation is imported for Date() and NSLog
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignInSwift
import GoogleSignIn
import os.log // Assuming you're still using os_log


@main
struct Seas_3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var selectedTabIndex: LoginViewSelection = .login

    // MARK: - Instantiate AllEnteredLocationsViewModel here
    @StateObject var allEnteredLocationsViewModel: AllEnteredLocationsViewModel

    // Use an initializer to set up your @StateObject
    init() {
        _allEnteredLocationsViewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(
            dataManager: PirateIslandDataManager(viewContext: PersistenceController.shared.container.viewContext)
        ))
        setupGlobalErrorHandler()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                appDelegate: appDelegate,
                selectedTabIndex: $selectedTabIndex,
                appState: appDelegate.appState
            )
            // MARK: - Inject ALL top-level EnvironmentObjects here
            // These objects will now be available to AppRootView and all its descendants.
            .environmentObject(appDelegate.authenticationState)
            .environmentObject(AuthViewModel.shared) // Ensure AuthViewModel.shared is always initialized before this
            .environmentObject(appDelegate.pirateIslandViewModel) // Assuming AppDelegate holds this
            .environmentObject(appDelegate.profileViewModel!) // Assuming AppDelegate holds this and it's non-nil
            .environmentObject(allEnteredLocationsViewModel) // Existing line
            .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext) // Ensure context is also in environment
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


struct AppRootView: View {
    let appDelegate: AppDelegate // We pass appDelegate to access its properties/dependencies
    @Binding var selectedTabIndex: LoginViewSelection
    @ObservedObject var appState: AppState // appState is passed directly, so keep it as @ObservedObject

    var body: some View {
        if appDelegate.isFirebaseConfigured {
            if appState.showWelcomeScreen {
                PirateIslandView(appState: appState)
                    .transition(.opacity)
                    .onAppear {
                        print("✅ Firebase is configured. Showing app content.")
                        print("👀 PirateIslandView appeared at \(Date())")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            print("⏰ Dismissing PirateIslandView at \(Date())")
                            withAnimation(.easeInOut(duration: 1)) {
                                appState.showWelcomeScreen = false
                            }
                        }
                        NSSetUncaughtExceptionHandler { exception in
                            NSLog("🔥 Uncaught Exception: %@", exception)
                            if let reason = exception.reason {
                                NSLog("🛑 Reason: %@", reason)
                            }
                        }
                    }
                    .onDisappear {
                        print("👋 PirateIslandView disappeared at \(Date())")
                    }
            } else {
                if appDelegate.authenticationState.isAuthenticated &&
                    appDelegate.authenticationState.navigateToAdminMenu {
                    AdminMenu()
                        // These environment objects are now provided by Seas_3App.
                        // You only need to explicitly set them here if AdminMenu
                        // needs a *different* instance than the global one,
                        // or if it's the root of a new environment subtree.
                        // Based on the goal, these are likely redundant now.
                        .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
                        // .environmentObject(appDelegate.authenticationState) // REMOVED (already global)
                        // .environmentObject(appState) // REMOVED (appState is passed as @ObservedObject to AppRootView)
                        // .environmentObject(appDelegate.profileViewModel!) // REMOVED (already global)
                } else if appDelegate.authenticationState.isAuthenticated &&
                            appDelegate.authenticationState.isLoggedIn {
                    IslandMenu(
                        isLoggedIn: Binding(
                            get: { appDelegate.authenticationState.isLoggedIn },
                            set: { appDelegate.authenticationState.setIsLoggedIn($0) }
                        ),
                        // Keep passing these directly as @ObservedObject if IslandMenu's init expects them this way
                        authViewModel: appDelegate.authViewModel,
                        profileViewModel: appDelegate.profileViewModel!
                    )
                    .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
                    // .environmentObject(appDelegate.authenticationState) // REMOVED (already global)
                    // .environmentObject(appState) // REMOVED (appState is passed as @ObservedObject)
                } else {
                    LoginView(
                        islandViewModel: PirateIslandViewModel(persistenceController: appDelegate.persistenceController),
                        profileViewModel: appDelegate.profileViewModel!, // Passed directly
                        isSelected: $selectedTabIndex,
                        navigateToAdminMenu: Binding(
                            get: { appDelegate.authenticationState.navigateToAdminMenu },
                            set: { appDelegate.authenticationState.navigateToAdminMenu = $0 }
                        ),
                        isLoggedIn: Binding(
                            get: { appDelegate.authenticationState.isLoggedIn },
                            set: { appDelegate.authenticationState.setIsLoggedIn($0) }
                        )
                    )
                    .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
                    // .environmentObject(appDelegate.authenticationState) // REMOVED (already global)
                }
            }
        } else {
            ProgressView("Configuring Firebase...")
                .onAppear {
                    print("⏳ Waiting for Firebase to configure...")
                }
        }
    }
}

// Optional: Extension for injecting PersistenceController via Environment
struct PersistenceControllerKey: EnvironmentKey {
    static var defaultValue: PersistenceController { PersistenceController.shared }
}

extension EnvironmentValues {
    var persistenceController: PersistenceController {
        get { self[PersistenceControllerKey.self] }
        set { self[PersistenceControllerKey.self] = newValue }
    }
}
