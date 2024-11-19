import AdSupport
import AppTrackingTransparency
import CoreData
import DeviceCheck
import FacebookCore
import FBSDKCoreKit
import FBSDKLoginKit
import Firebase
import FirebaseAnalytics
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseDatabase
import GoogleMobileAds
import GoogleSignIn
import SwiftUI
import UIKit
import UserNotifications

extension NSNotification.Name {
    static let signInLinkReceived = NSNotification.Name("signInLinkReceived")
}

class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
    var window: UIWindow?
    let persistenceController = PersistenceController.shared
    
    // Configuration properties
    var facebookSecret: String?
    var sendgridApiKey: String?
    var googleClientID: String?
    var googleApiKey: String?
    var googleAppID: String?
    var deviceCheckKeyID: String? // Add this
    var deviceCheckTeamID: String? // Add this

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureApplicationAppearance()
        
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        print("Configuring Firebase...")
        configureFirebase()
        print("Firebase configured")
        
        // Create Firestore collection after Firebase configuration
        Firestore.firestore().collection("appDayOfWeeks").addDocument(data: [:]) { error in
            if let error = error {
                print("Error creating collection: \(error)")
            } else {
                print("Collection created successfully")
            }
        }
        
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

        // Get FacebookAppID from Info.plist
        let infoPlist = Bundle.main.infoDictionary
        let facebookAppID = infoPlist?["FacebookAppID"] as? String

        // Set FacebookAppID
        Settings.shared.appID = facebookAppID
        
        // Configure Firebase.
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.debug)

        // Initialize Firestore
        let settings = FirestoreSettings()
        Firestore.firestore().settings = settings
        
        // Log Firestore initialization
        print("Firestore initialized")
        print("Firestore settings: \(settings)")


        // Enable Firebase debug logging
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
    
    // Helper function to retrieve SendGrid API Key from Config.plist
    private func getSendGridApiKey() -> String? {
        guard let config = ConfigLoader.loadConfigValues() else {
            print("Failed to load Config.plist")
            return nil
        }
        return config.SENDGRID_API_KEY
    }

    // Loading configuration values
    private func loadConfigValues() {
        guard let config = ConfigLoader.loadConfigValues() else {
            print("Could not load configuration values.")
            return
        }
        sendgridApiKey = config.SENDGRID_API_KEY
        googleClientID = config.GoogleClientID
        googleApiKey = config.GoogleApiKey
        googleAppID = config.GoogleAppID
        deviceCheckKeyID = config.DeviceCheckKeyID
        deviceCheckTeamID = config.DeviceCheckTeamID

        // Ensure SendGrid API key is set, else print error
        guard let sendgridApiKey = sendgridApiKey else {
            print("Error: SendGrid API Key is missing from Config.plist")
            // Provide a default value or disable SendGrid functionality
            AppConfig.shared.sendgridApiKey = "DEFAULT_SENDGRID_API_KEY"
            return
        }

        // Load into AppConfig (if needed)
        AppConfig.shared.googleClientID = googleClientID
        AppConfig.shared.googleApiKey = googleApiKey
        AppConfig.shared.googleAppID = googleAppID
        AppConfig.shared.sendgridApiKey = sendgridApiKey
        AppConfig.shared.deviceCheckKeyID = deviceCheckKeyID
        AppConfig.shared.deviceCheckTeamID = deviceCheckTeamID
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
    
    private func reverifyEmail(for email: String, password: String) {
        // Ensure Firebase Authentication is initialized
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Email verification failed: \(error.localizedDescription)")
            } else {
                print("Email verification successful for: \(email)")
            }
        }
    }

    private func configureApplicationAppearance() {
        UINavigationBar.appearance().tintColor = .systemOrange
        UITabBar.appearance().tintColor = .systemOrange
    }
}
