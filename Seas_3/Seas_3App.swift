import SwiftUI
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignInSwift
import GoogleSignIn

@main
struct Seas_3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var selectedTabIndex: LoginViewSelection = .login

    var body: some Scene {
        WindowGroup {
            AppRootView(
                appDelegate: appDelegate,
                selectedTabIndex: $selectedTabIndex,
                appState: appDelegate.appState   // Pass shared instance directly
            )
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
    let appDelegate: AppDelegate
    @Binding var selectedTabIndex: LoginViewSelection
    @ObservedObject var appState: AppState

    var body: some View {
        if appDelegate.isFirebaseConfigured {
            if appState.showWelcomeScreen {
                PirateIslandView(appState: appState)
                    .transition(.opacity)
                    // Removed .animation modifier here
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
                        .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
                        .environmentObject(appDelegate.authenticationState)
                        .environmentObject(appState)
                        .environmentObject(appDelegate.profileViewModel!)
                } else if appDelegate.authenticationState.isAuthenticated &&
                            appDelegate.authenticationState.isLoggedIn {
                    IslandMenu(
                        isLoggedIn: Binding(
                            get: { appDelegate.authenticationState.isLoggedIn },
                            set: { appDelegate.authenticationState.isLoggedIn = $0 }
                        ),
                        authViewModel: appDelegate.authViewModel,
                        profileViewModel: appDelegate.profileViewModel!
                    )
                    .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
                    .environmentObject(appDelegate.authenticationState)
                    .environmentObject(appState)
                } else {
                    LoginView(
                        islandViewModel: PirateIslandViewModel(persistenceController: appDelegate.persistenceController),
                        profileViewModel: appDelegate.profileViewModel!,
                        isSelected: $selectedTabIndex,
                        navigateToAdminMenu: Binding(
                            get: { appDelegate.authenticationState.navigateToAdminMenu },
                            set: { appDelegate.authenticationState.navigateToAdminMenu = $0 }
                        ),
                        isLoggedIn: Binding(
                            get: { appDelegate.authenticationState.isLoggedIn },
                            set: { appDelegate.authenticationState.isLoggedIn = $0 }
                        )
                    )
                    .environment(\.managedObjectContext, appDelegate.persistenceController.container.viewContext)
                    .environmentObject(appDelegate.authenticationState)
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
