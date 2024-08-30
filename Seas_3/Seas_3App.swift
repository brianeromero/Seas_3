// Seas_3App.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import SwiftUI
import CoreData
import Combine


@main
struct Seas3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @StateObject var viewModel: AppDayOfWeekViewModel

    init() {
        let repository = AppDayOfWeekRepository(persistenceController: PersistenceController.shared)
        _viewModel = StateObject(wrappedValue: AppDayOfWeekViewModel(
            selectedIsland: nil,
            repository: repository
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
