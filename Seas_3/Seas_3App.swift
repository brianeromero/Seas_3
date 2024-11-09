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
                    print("Google URL handled: \(url)")
                }
            }
    }
}

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
            URLHandler()
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
                AdminMenu(
                    persistenceController: PersistenceController.shared,
                    appDayOfWeekRepository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                    enterZipCodeViewModel: EnterZipCodeViewModel(
                        repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
                        context: PersistenceController.shared.container.viewContext
                    ),
                    appDayOfWeekViewModel: viewModel
                )
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(appState)
                .environmentObject(viewModel)
                .onAppear {
                    setupGlobalErrorHandler()
                }
            } else if authenticationState.isAuthenticated && authenticationState.isLoggedIn {
                IslandMenu(
                    persistenceController: PersistenceController.shared,
                    isLoggedIn: $authenticationState.isLoggedIn,
                    profileViewModel: ProfileViewModel(
                        viewContext: PersistenceController.shared.container.viewContext
                    )
                )
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(appState)
                .environmentObject(viewModel)
                .onAppear {
                    let sceneLoader = SceneLoader()
                    sceneLoader.loadScene()
                    setupGlobalErrorHandler()
                }
            } else {
                LoginView(
                    islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                    persistenceController: PersistenceController.shared, // Replaced placeholder
                    isSelected: $selectedTabIndex,
                    navigateToAdminMenu: $authenticationState.navigateToAdminMenu,
                    isLoggedIn: $authenticationState.isLoggedIn
                )
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environmentObject(authenticationState)
                .onAppear {
                    setupGlobalErrorHandler()
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
