import SwiftUI
import Foundation // Make sure Foundation is imported for Date() and NSLog
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignInSwift
import GoogleSignIn
import os.log // Assuming you're still using os_log
import FirebaseCore
import FirebaseAuth // Assuming you need this for AuthViewModel.shared
import FirebaseFirestore // Assuming you need this for Firestore


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
            AppRootView( // No appDelegate parameter here anymore
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
    @EnvironmentObject var authenticationState: AuthenticationState
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel

    @Binding var selectedTabIndex: LoginViewSelection
    @ObservedObject var appState: AppState

    @State private var navigationPath = NavigationPath() // This is your ONE TRUE NavigationPath

    @State private var showInitialSplash = true

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // If you want a splash screen on launch:
            if showInitialSplash {
                PirateIslandView(appState: appState) // Assuming this is your splash
                    .onAppear {
                        print("AppRootView: Showing Initial Splash (PirateIslandView)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // Adjust time
                            withAnimation(.easeInOut(duration: 1)) {
                                showInitialSplash = false // Dismiss splash
                            }
                        }
                    }
            } else if authenticationState.isAuthenticated {
                // Authenticated Content
                DebugPrintView("AppRootView: AuthenticationState.isAuthenticated is TRUE. Displaying Authenticated Content.")

                if authenticationState.navigateToAdminMenu {
                    AdminMenu()
                        .onAppear { print("AppRootView: AdminMenu has appeared.") }
                } else {
                    IslandMenu2(
                        profileViewModel: profileViewModel,
                        navigationPath: $navigationPath // ✅ Add this binding
                    )
                    .onAppear { print("AppRootView: IslandMenu has appeared.") }
                }
            } else {
                // Unauthenticated Content (Login)
                DebugPrintView("AppRootView: AuthenticationState.isAuthenticated is FALSE. Displaying LoginView.")
                LoginView(
                    islandViewModel: pirateIslandViewModel,
                    profileViewModel: profileViewModel,
                    isSelected: $selectedTabIndex,
                    navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                    isLoggedIn: $authenticationState.isLoggedIn,
                    navigationPath: $navigationPath  // <-- pass binding here
                )

                .onAppear { print("AppRootView: LoginView has appeared.") }
            }
        }
        .onChange(of: authenticationState.isAuthenticated) { oldValue, newValue in
            print("AppRootView onChange: authenticationState.isAuthenticated changed from \(oldValue) to \(newValue)")
            if !newValue {
                // Always clear navigation path on logout
                navigationPath = NavigationPath()
                print("DEBUG: AppRootView - Navigation path cleared (due to unauthenticated state).")
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
