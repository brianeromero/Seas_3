// Seas_3App.swift
// Seas_3
// Created by Brian Romero on 6/24/24.

import SwiftUI
import CoreData
import Combine

@main
struct Seas3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let persistenceController = PersistenceController.shared
    @StateObject var appState = AppState()
    
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
                        .environment(\.managedObjectContext, persistenceController.viewContext)
                        .environmentObject(appState)
                        .onAppear {
                            let sceneLoader = SceneLoader()
                            sceneLoader.loadScene()
                        }
                }
            }
            .environmentObject(persistenceController) // Inject PersistenceController globally
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
