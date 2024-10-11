// Seas_3App.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import SwiftUI
import CoreData
import Combine
import FBSDKCoreKit // Import Facebook SDK
import GoogleSignIn // Import Google Sign-In SDK
<<<<<<< HEAD
=======

>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9

@main
struct Seas3App: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var viewModel: AppDayOfWeekViewModel
    @StateObject var authenticationState = AuthenticationState() // New authentication state

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
                } else if !authenticationState.isAuthenticated {
<<<<<<< HEAD
                    // Create instances of the required view model and context
                    let context = PersistenceController.shared.viewContext
                    let islandViewModel = PirateIslandViewModel(context: context)

                    // Pass them to the LoginView
                    LoginView(islandViewModel: islandViewModel, context: context)
=======
                    LoginView()
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
                        .environmentObject(authenticationState) // Pass authentication state
                } else {
                    IslandMenu()
                        .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
                        .environmentObject(appState)
                        .environmentObject(viewModel) // Inject ViewModel globally
                        .onAppear {
                            let sceneLoader = SceneLoader()
                            sceneLoader.loadScene()
                        }
                }
            }
            .environmentObject(PersistenceController.shared) // Inject PersistenceController globally
            .onAppear {
                setupGlobalErrorHandler()
            }
            .onOpenURL { url in
                // Handle URL for Google Sign-In and Facebook Login
                if ApplicationDelegate.shared.application(UIApplication.shared, open: url) {
                    print("Facebook URL handled: \(url)")
                } else if GIDSignIn.sharedInstance.handle(url) {
                    print("Google URL handled: \(url)")
                }
            }
        }
    }

    private func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler { exception in
            if let reason = exception.reason,
               reason.contains("has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API") {
                NSLog("Caught NaN error: %@", reason)
            }
        }
    }
}
