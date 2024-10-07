import UIKit
import CoreData
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // Access the shared PersistenceController
    let persistenceController = PersistenceController.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Custom initialization if needed
        return true
    }

    // Handle URL for Google Sign-In
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // Save context when the app enters the background
    func applicationDidEnterBackground(_ application: UIApplication) {
        do {
            try persistenceController.saveContext()
        } catch {
            print("Failed to save context when entering background: \(error.localizedDescription)")
        }
    }

    // Save context when the app is about to terminate
    func applicationWillTerminate(_ application: UIApplication) {
        do {
            try persistenceController.saveContext()
        } catch {
            print("Failed to save context when terminating: \(error.localizedDescription)")
        }
    }
}
