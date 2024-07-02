//
//  Seas_3App.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine

@main
struct Seas3App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // Link to your AppDelegate
    
    private let persistenceController = PersistenceController.shared
    @StateObject var appState = AppState() // Use @StateObject for AppState
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.showWelcomeScreen {
                    PirateIslandView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                appState.showWelcomeScreen = false
                            }
                        }
                } else {
                    IslandMenu() // Use IslandMenu as the main view
                        .environment(\.managedObjectContext, persistenceController.viewContext)
                        .environmentObject(appState) // Inject AppState as environment object
                        .onAppear {
                            let sceneLoader = SceneLoader()
                            sceneLoader.loadScene()
                        }
                }
            }
            .onAppear {
                setupGlobalErrorHandler()
                // Perform any UIKit-related setup here if necessary
                // For example:
                // UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
    
    private func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler { exception in
            // Check if the exception reason contains the NaN error message
            if let reason = exception.reason,
               reason.contains("has passed an invalid numeric value (NaN, or not-a-number) to CoreGraphics API") {
                // Log the error
                NSLog("Caught NaN error: %@", reason)
            }
        }
    }
}
