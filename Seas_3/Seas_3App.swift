// Seas_3App.swift
// Seas_3
// Created by Brian Romero on 6/24/24.


import SwiftUI
import CoreData
import Combine
import FBSDKCoreKit
import GoogleSignIn


@main
struct Seas3App: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var viewModel: AppDayOfWeekViewModel
    @StateObject var authenticationState = AuthenticationState()
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
                } else if !authenticationState.isAuthenticated {
                    LoginView(
                        islandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared),
                        persistenceController: PersistenceController.shared,
                        isSelected: $selectedTabIndex
                    )
                        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                        .environmentObject(authenticationState)
                } else {
                    IslandMenu(persistenceController: PersistenceController.shared)
                        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                        .environmentObject(appState)
                        .environmentObject(viewModel)
                        .onAppear {
                            let sceneLoader = SceneLoader()
                            sceneLoader.loadScene()
                        }
                }
            }
            .environmentObject(PersistenceController.shared)
            .onAppear {
                setupGlobalErrorHandler()
            }
            .onOpenURL { url in
                if ApplicationDelegate.shared.application(UIApplication.shared, open: url, options: [:]) {
                    print("Facebook URL handled: \(url)")
                } else if GIDSignIn.sharedInstance.handle(url) {
                    print("Google URL handled: \(url)")
                }
            }
        }
    }

    private func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler { exception in
            // Log the exception
            NSLog("Uncaught Exception: %@", exception)
            
            // Handle specific exceptions
            if let reason = exception.reason,
               reason.contains("has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API") {
                NSLog("Caught NaN error: %@", reason)
            }
            
            // Optional: Terminate the app or display an error message
        }
    }
}
