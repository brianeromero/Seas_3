import SwiftUI
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignIn

@main
struct Seas3App: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var authenticationState = AuthenticationState()
    
    // Declare viewModel without initializing here
    @StateObject var viewModel: AppDayOfWeekViewModel

    @State private var selectedTabIndex: LoginViewSelection = .login

    init() {
        let persistenceController = PersistenceController.shared
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let enterZipCodeViewModel = EnterZipCodeViewModel(repository: repository, context: persistenceController.container.viewContext)
        _viewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: repository,
            enterZipCodeViewModel: enterZipCodeViewModel
        ))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.showWelcomeScreen {
                    PirateIslandView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                withAnimation {
                                    appState.showWelcomeScreen = false
                                }
                            }
                        }
                } else if authenticationState.isAuthenticated && authenticationState.navigateToAdminMenu {
                    AdminMenu()
                        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                        .environmentObject(appState)
                        .environmentObject(viewModel)
                } else if authenticationState.isAuthenticated && authenticationState.isLoggedIn {
                    IslandMenu(persistenceController: PersistenceController.shared, isLoggedIn: $authenticationState.isLoggedIn, profileViewModel: ProfileViewModel(viewContext: PersistenceController.shared.container.viewContext)) // Provide ProfileViewModel
                        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                        .environmentObject(appState)
                        .environmentObject(viewModel)
                        .onAppear {
                            let sceneLoader = SceneLoader()
                            sceneLoader.loadScene()
                        }
                } else {
                    LoginView(
                        islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                        persistenceController: PersistenceController.shared,
                        isSelected: $selectedTabIndex,
                        navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                        isLoggedIn: $authenticationState.isLoggedIn
                    )
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                    .environmentObject(authenticationState)
                }
            }
            .environmentObject(authenticationState)
            .onAppear {
                setupGlobalErrorHandler()
            }
            .onOpenURL { url in
                if url.absoluteString.contains("fb") {
                    print("Facebook URL handled: \(url)")
                } else if GIDSignIn.sharedInstance.handle(url) {
                    print("Google URL handled: \(url)")
                }
            }
        }
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
