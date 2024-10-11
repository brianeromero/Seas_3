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
        let context = persistenceController.container.viewContext
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        do {
            let userInfo = try context.fetch(request)
            if let user = userInfo.first {
                let userName = user.userName
                
                if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value,
                   let email = components?.queryItems?.first(where: { $0.name == "email" })?.value {
                    let emailManager = UnifiedEmailManager(managedObjectContext: context)
                    emailManager.verifyEmail(token: token, email: email, userName: userName) { success in
                        if success {
                            // Verification successful, redirect to success.html
                            let url = URL(string: "http://mfinderbjj.rf.gd/success.html")!
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            print("Email verification successful")
                        } else {
                            // Verification failed, redirect to failed.html
                            let url = URL(string: "http://mfinderbjj.rf.gd/failed.html")!
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                            print("Email verification failed")
                        }
                    }
                    return true
                }
            }
        } catch {
            print("Error fetching UserInfo: \(error.localizedDescription)")
        }
        
        // Handle custom URL scheme
        if url.scheme == "matfinder" && url.host == "verify-success" {
            // Show dashboard or update UI
            window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DashboardViewController")
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
