import SwiftUI
import UIKit
import CoreData
import GoogleSignIn
import FBSDKCoreKit
import FirebaseCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // Access the shared PersistenceController
    let persistenceController = PersistenceController.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Firebase initialization
        FirebaseApp.configure()
        
        // Facebook SDK initialization
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Custom initialization if needed
        return true
    }

    // Handle URL for Google Sign-In, Facebook Login, and Email Verification
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle Facebook Login
        if ApplicationDelegate.shared.application(app, open: url, options: options) {
            print("Facebook URL handled: \(url)")
            return true
        }
        
        // Handle Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            print("Google URL handled: \(url)")
            return true
        }
        
        // Handle Email Verification
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value,
           let email = components?.queryItems?.first(where: { $0.name == "email" })?.value {
            let emailManager = UnifiedEmailManager(managedObjectContext: persistenceController.container.viewContext)
            emailManager.verifyEmail(token: token, email: email) { success in
                if success {
                    print("Email verification successful")
                } else {
                    print("Email verification failed")
                }
            }
            return true
        }
        
        return false
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
