import SwiftUI
import UIKit
import CoreData
import GoogleSignIn
import FBSDKCoreKit
import FirebaseCore
import Firebase
import FirebaseAppCheck
import FacebookCore
import DeviceCheck
import FirebaseAnalytics
import FirebaseMessaging
import AppTrackingTransparency
import AdSupport
import GoogleMobileAds
import FBSDKLoginKit



class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
    var window: UIWindow?

    // Access the shared PersistenceController
    let persistenceController = PersistenceController.shared

    // Variables to store config values
    var facebookAppID: String?
    var facebookClientToken: String?
    var facebookSecret: String?
    var sendgridApiKey: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Load Config.plist values
        loadConfigValues()

        // Firebase initialization
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        Analytics.setAnalyticsCollectionEnabled(true)
        Messaging.messaging().isAutoInitEnabled = false

        // Facebook SDK initialization
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Request App Tracking Transparency permission
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    let idfa = ASIdentifierManager.shared().advertisingIdentifier
                    print("IDFA Access Granted: \(idfa)")
                case .denied, .restricted, .notDetermined:
                    print("IDFA Access Denied or Restricted")
                @unknown default:
                    print("Unknown status")
                }
            }
        }

        // Custom initialization if needed
        let settings = Settings()
        print("Facebook Advertiser ID Collection Enabled: \(settings.isAdvertiserIDCollectionEnabled)")
        return true
    }

    // Handle Facebook SDK errors
    func handleFacebookSDKError(_ error: Error) {
        let errorCode = (error as NSError).code
        switch errorCode {
        case 190:
            print("Invalid OAuth access token signature. Please try again.")
        default:
            print("Unknown Facebook SDK error: \(error.localizedDescription)")
        }
    }

    // MessagingDelegate methods
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        // Handle FCM token
    }

    func messaging(_ messaging: Messaging, didReceive remoteMessage: Any) {
        print("Received remote message: \(remoteMessage)")
        // Handle remote message
    }

    // Load sensitive config values from Config.plist
    func loadConfigValues() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist") else {
            print("Config.plist file not found")
            return
        }

        guard let config = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Failed to load Config.plist")
            return
        }

        facebookAppID = config["FacebookAppID"] as? String
        facebookClientToken = config["FacebookClientToken"] as? String
        facebookSecret = config["FacebookSecret"] as? String
        sendgridApiKey = config["SENDGRID_API_KEY"] as? String

        print("Loaded FacebookAppID: \(facebookAppID ?? "")")
        print("Loaded SendGrid API Key: \(sendgridApiKey ?? "")")
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Handle Facebook Login
        if ApplicationDelegate.shared.application(app, open: url, options: options) {
            if AccessToken.current?.isExpired ?? false {
                print("Facebook token expired")
            } else {
                handleFacebookLogin()
            }
            return true
        }

        // Handle Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            print("Google URL handled: \(url)")
            return true
        }

        // Handle Email Verification and custom URL schemes
        handleEmailVerification(url: url)

        return false
    }

    
    // Define the fetchFacebookUserProfile method
    func fetchFacebookUserProfile() {
        GraphRequest(graphPath: "me", parameters: ["fields": "id, name, email"]).start { connection, result, error in
            if let error = error {
                print("Error fetching Facebook profile: \(error.localizedDescription)")
                return
            }
            
            guard let result = result as? [String: Any] else {
                print("Invalid Facebook profile result")
                return
            }
            
            print("Facebook profile: \(result)")
            // Handle Facebook profile data
        }
    }

    // Call the fetchFacebookUserProfile method in handleFacebookLogin
    func handleFacebookLogin() {
        LoginManager().logIn(permissions: ["public_profile", "email"], from: nil) { [weak self] result, error in
            if let error = error {
                print("Error logging in: \(error.localizedDescription)")
            } else if let _ = result {
                print("Logged in successfully")
                self?.fetchFacebookUserProfile()
            } else if result?.isCancelled == true {
                print("User cancelled login")
            }
        }
    }
    // Handle Email Verification
    func handleEmailVerification(url: URL) {
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
                        let redirectURL = success ? "http://mfinderbjj.rf.gd/success.html" : "http://mfinderbjj.rf.gd/failed.html"
                        UIApplication.shared.open(URL(string: redirectURL)!, options: [:], completionHandler: nil)
                        print(success ? "Email verification successful" : "Email verification failed")
                    }
                }
            }
        } catch {
            print("Error fetching UserInfo: \(error.localizedDescription)")
        }
    }

    // Save context when the app enters the background
    func applicationDidEnterBackground(_ application: UIApplication) {
        saveContext()
    }

    // Save context when the app is about to terminate
    func applicationWillTerminate(_ application: UIApplication) {
        saveContext()
    }

    // Helper to save context
    private func saveContext() {
        do {
            try persistenceController.saveContext()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}
