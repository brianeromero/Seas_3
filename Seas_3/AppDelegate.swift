//
//  AppDelegate.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import UIKit
import CoreData

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // Access the shared PersistenceController
    let persistenceController = PersistenceController.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Custom initialization if needed
        return true
    }

    // You can call saveContext at appropriate lifecycle events
    func applicationDidEnterBackground(_ application: UIApplication) {
        do {
            try persistenceController.saveContext() // Save changes when the app goes to the background
        } catch {
            print("Failed to save context when entering background: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        do {
            try persistenceController.saveContext() // Save changes when the app is about to terminate
        } catch {
            print("Failed to save context when terminating: \(error.localizedDescription)")
        }
    }
}
