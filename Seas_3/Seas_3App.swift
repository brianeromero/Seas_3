import SwiftUI
import Foundation // Make sure Foundation is imported for Date() and NSLog
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignInSwift
import GoogleSignIn
import os.log // Assuming you're still using os_log
import FirebaseCore


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

    // Use a @State for NavigationPath if you want programmatic control over the stack
    @State private var navigationPath = NavigationPath()

    var body: some View {
        // --- Add the NavigationStack here ---
        NavigationStack(path: $navigationPath) { // <--- This is the key change!
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
                        }
                        .onDisappear {
                            print("👋 PirateIslandView disappeared at \(Date())")
                        }
                } else {
                    // This is the content shown AFTER the welcome screen,
                    // which is either authenticated or unauthenticated.
                    if appDelegate.authenticationState.isAuthenticated {
                        // If authenticated, decide between AdminMenu and IslandMenu
                        if appDelegate.authenticationState.navigateToAdminMenu {
                            AdminMenu()
                                // Environment objects are already passed from Seas_3App
                        } else {
                            IslandMenu(
                                isLoggedIn: Binding(
                                    get: { appDelegate.authenticationState.isLoggedIn },
                                    set: { appDelegate.authenticationState.setIsLoggedIn($0) }
                                ),
                                authViewModel: appDelegate.authViewModel,
                                profileViewModel: appDelegate.profileViewModel!
                            )
                        }
                    } else {
                        // If not authenticated, show the LoginView
                        LoginView(
                            islandViewModel: appDelegate.pirateIslandViewModel, // Use the shared instance from appDelegate
                            profileViewModel: appDelegate.profileViewModel!,
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
                    }
                }
            } else {
                ProgressView("Configuring Firebase...")
                    .onAppear {
                        print("⏳ Waiting for Firebase to configure...")
                    }
            }
        } // <--- End of NavigationStack
        // --- End of NavigationStack here ---
        .onChange(of: appDelegate.authenticationState.isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                // When logging out, clear the navigation path
                navigationPath = NavigationPath()
                print("DEBUG: AppRootView - Authentication state changed to unauthenticated. Navigation path cleared.")
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
