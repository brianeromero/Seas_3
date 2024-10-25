import UIKit
import Firebase
import FirebaseCore
import FirebaseAppCheck
import FirebaseDatabase
import SwiftUI
import CoreData
import GoogleSignIn
import FBSDKCoreKit
import FacebookCore
import DeviceCheck
import FirebaseAnalytics
import FirebaseMessaging
import AppTrackingTransparency
import AdSupport
import GoogleMobileAds
import FBSDKLoginKit
import UserNotifications
import FirebaseFirestore
import FirebaseAuth


extension NSNotification.Name {
    static let signInLinkReceived = NSNotification.Name("signInLinkReceived")
}


class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
    var window: UIWindow?
    let persistenceController = PersistenceController.shared
    
    // Configuration properties
    var facebookAppID: String?
    var facebookClientToken: String?
    var facebookSecret: String?
    var sendgridApiKey: String?
    var googleClientID: String?
    var googleApiKey: String?
    var googleAppID: String?


    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication
                       .LaunchOptionsKey: Any]?) -> Bool {
        print("Configuring Firebase...")
        configureFirebase()
        print("Firebase configured")
        
        print("Configuring App Check...")
        setupAppCheck()
        print("App Check configured")
        print("Setting App Check provider factory: \(SeasAppCheckProviderFactory.self)")
        
        print("Configuring Google Ads...")
        configureGoogleAds()
        print("Google Ads configured")
        
        print("Requesting IDFA permission...")
        IDFAHelper.requestIDFAPermission()
        print("IDFA permission requested")
        
        print("Loading config values...")
        loadConfigValues()
        print("Config values loaded")
        
        print("Registering for push notifications...")
        registerForPushNotifications()
        print("Push notifications registered")
        
        // Additional logging
        print("Device Information:")
        print("  Model: \(UIDevice.current.model)")
        print("  System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        print("  UUID: \(UIDevice.current.identifierForVendor?.uuidString ?? "")")
        
        return true
    }
    
    
    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else {
                print("User denied notification permission")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        FacebookHelper.checkFacebookToken()
    }

    private func configureGoogleAds() {
         GADMobileAds.sharedInstance().requestConfiguration.setPublisherFirstPartyIDEnabled(false)
     }

    private func configureFirebase() {
        // Set app check provider factory *before* configuring Firebase.
        let appCheckFactory = SeasAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(appCheckFactory)

        // Now configure Firebase.
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
        Analytics.setAnalyticsCollectionEnabled(true)

        // Additional logging
        print("Firebase Configuration:")
        if let googleAppID = getGoogleAppID() {
            print("  Firebase App ID: \(googleAppID)")
        } else {
            print("  Firebase App ID not found")
        }
    }

    func getGoogleAppID() -> String? {
        if let infoPlist = Bundle.main.infoDictionary,
           let googleAppID = infoPlist["GOOGLE_APP_ID"] as? String {
            return googleAppID
        } else if let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
                  let dict = NSDictionary(contentsOf: url) as? [String: Any],
                  let googleAppID = dict["GOOGLE_APP_ID"] as? String {
            return googleAppID
        } else {
            return nil
        }
    }
    
    // Define AppCheckTokenError enum
    enum AppCheckTokenError: Error {
        case noTokenReceived
        case invalidToken
    }

    private func setupAppCheck() {
        print("Setting up App Check...")
        
        let factory = SeasAppCheckProviderFactory()
        print("Creating App Check provider factory: \(factory)")
        
        AppCheck.setAppCheckProviderFactory(factory)
        print("App Check provider factory set successfully")
        
        print("Using AppAttestProvider (iOS 14+)")
        print("Fetching App Check token...")
        
        fetchAppCheckToken()
    }

    private func fetchAppCheckToken() {
        print("Fetching App Check token...")
        let appCheck = AppCheck.appCheck()
        appCheck.token(forcingRefresh: true) { [weak self] (appCheckToken: AppCheckToken?, error: Error?) in
            guard self != nil else { return }
            
            print("App Check token callback received")
            
            if let error = error {
                print("Error fetching App Check token: \(error.localizedDescription)")
                print("  Error: \(error)")
                self?.handleAppCheckTokenError(error)
            } else if let appCheckToken = appCheckToken {
                print("App Check token received: \(appCheckToken.token)")
                print("  Token: \(appCheckToken.token)")
                self?.storeAppCheckToken(appCheckToken.token)
            } else {
                print("No App Check token received")
                self?.handleAppCheckTokenError(AppCheckTokenError.noTokenReceived)
            }
        }
    }

    private func storeAppCheckToken(_ token: String) {
        print("Storing App Check token: \(token)")
        // Store the token securely
    }

    private func handleAppCheckTokenError(_ error: Error) {
        print("Handling App Check token error: \(error)")
    }
    
    private func loadConfigValues() {
        guard let config = loadPlistConfig() else {
            print("Could not load configuration values.")
            return
        }
        
        facebookAppID = config.FacebookAppID
        facebookClientToken = config.FacebookClientToken
        facebookSecret = config.FacebookSecret
        sendgridApiKey = config.SENDGRID_API_KEY
        googleClientID = config.GoogleClientID
        googleApiKey = config.GoogleApiKey
        googleAppID = config.GoogleAppID

        // Load into AppConfig
        AppConfig.shared.facebookAppID = facebookAppID
        AppConfig.shared.googleClientID = googleClientID
        AppConfig.shared.googleApiKey = googleApiKey
        AppConfig.shared.googleAppID = googleAppID
        AppConfig.shared.sendgridApiKey = sendgridApiKey
    }

    private func loadPlistConfig() -> Config? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let config = try? PropertyListDecoder().decode(Config.self, from: data) else {
            print("Failed to load Config.plist")
            return nil
        }
        return config
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        
        let tokenDict = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(name: Notification.Name("FCMTokenReceived"), object: nil, userInfo: tokenDict)
        
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching Firebase registration token: \(error)")
            } else if let token = token {
                print("Firebase registration token: \(token)")
            }
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if ApplicationDelegate.shared.application(app, open: url, options: options) {
            return true
        }

        if GIDSignIn.sharedInstance.handle(url) {
            print("Google URL Handled: \(url)")
            return true
        }

        if Auth.auth().isSignIn(withEmailLink: url.absoluteString) {
            NotificationCenter.default.post(name: .signInLinkReceived, object: url.absoluteString)
            return true
        }

        EmailVerificationHandler.handleEmailVerification(url: url)

        return false
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        saveContext()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        saveContext()
    }

    private func saveContext() {
        do {
            try persistenceController.saveContext()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
}
