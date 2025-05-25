// Apple Frameworks
import UIKit
import SwiftUI
import CoreData
import UserNotifications
import AppTrackingTransparency
import AdSupport
import DeviceCheck

// Firebase
import FirebaseAppCheck
import FirebaseAnalytics
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging


// Google
import GoogleMobileAds
import GoogleSignInSwift
import GoogleSignIn

import Security


// Facebook
import FacebookCore
import FBSDKCoreKit
import FBSDKLoginKit

// AdServices
import AdServices

extension NSNotification.Name {
    static let signInLinkReceived = NSNotification.Name("signInLinkReceived")
    static let fcmTokenReceived = NSNotification.Name("FCMTokenReceived")
}

class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    let appConfig = AppConfig.shared

    // Config values
    var facebookSecret: String?
    var sendgridApiKey: String?
    var googleClientID: String?
    var googleApiKey: String?
    var googleAppID: String?
    var deviceCheckKeyID: String?
    var deviceCheckTeamID: String?

    var isFirebaseConfigured = false

    enum AppCheckTokenError: Error {
        case noTokenReceived, invalidToken
    }


    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // ✅ 1. Configure Firebase & App Check first
        configureFirebaseIfNeeded()
        
        // ✅ 2. Facebook SDK (after Firebase)
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // ✅ 3. Optional Debug flag
        UserDefaults.standard.set(true, forKey: "AppAuthDebug")
        
        // ✅ 4. App-specific config/setup
        configureAppConfigValues()
        configureApplicationAppearance()
        configureGoogleSignIn()
        configureNotifications(for: application)
        configureGoogleAds()

        // ✅ 5. Safe to sync Firestore after Firebase is fully initialized
       // FirestoreSyncManager.shared.syncInitialFirestoreData()

        // ✅ 6. Defer Keychain test to avoid premature access
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testKeychainAccessGroup()
        }
    
        // ✅ 7.IDFA request — independent of Firebase
        IDFAHelper.requestIDFAPermission()
    
        // ✅ 8. DO NOT REGISTER DebugURLProtocol unless absolutely necessary
        
        /*
        #if DEBUG
        URLProtocol.registerClass(DebugURLProtocol.self)
        #endif
        */

        return true
    }


    func testKeychainAccessGroup() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "testAccount",
            kSecAttrService as String: "testService",
            kSecAttrAccessGroup as String: "com.google.iid", // Change to the keychain group you want to test
            kSecReturnAttributes as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            print("✅ Access group is accessible: \(result!)")
        } else if status == errSecItemNotFound {
            print("🔍 Access group is available, item not found — that’s okay.")
        } else {
            print("❌ Keychain access failed: \(status)")
        }
    }


    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("📬 openURL: \(url)")

        let facebookHandled = ApplicationDelegate.shared.application(app, open: url, options: options)
        let googleHandled = GIDSignIn.sharedInstance.handle(url)

        return facebookHandled || googleHandled
    }

    

    private func fetchAppCheckToken() {
        let appCheck = AppCheck.appCheck()
        appCheck.token(forcingRefresh: true) { [weak self] (appCheckToken: AppCheckToken?, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                print("[App Check] Error fetching token: \(error.localizedDescription)")
                self.handleAppCheckTokenError(error)
            } else if let appCheckToken = appCheckToken {
                print("[App Check] Token received: \(appCheckToken.token)")
                self.storeAppCheckToken(appCheckToken.token)
            } else {
                print("[App Check] No token received.")
                self.handleAppCheckTokenError(AppCheckTokenError.noTokenReceived)
            }
        }
    }

    private func storeAppCheckToken(_ token: String) {
        // Implement secure token storage
        print("Storing App Check token: \(token)")
    }

    private func handleAppCheckTokenError(_ error: Error) {
        print("Handling App Check token error: \(error)")
    }

    private func configureGoogleAds() {
        let adsInstance = GADMobileAds.sharedInstance()

        // Optional: disable publisher first party ID if needed
        adsInstance.requestConfiguration.setPublisherFirstPartyIDEnabled(false)

        // Required: Initialize Google Mobile Ads SDK
        adsInstance.start { status in
            print("✅ Google Mobile Ads SDK initialized with status: \(status.adapterStatusesByClassName)")
        }
    }




    private func registerForPushNotifications(completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else {
                print("User denied notification permission")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                Messaging.messaging().token { token, error in
                    if let error = error {
                        print("Error fetching FCM registration token: \(error)")
                    } else if let token = token {
                        print("FCM registration token: \(token)")
                        self.handleFCMToken(token)
                    }
                    completion()
                }
            }
        }
    }

    private func handleFCMToken(_ token: String) {
        // Unify FCM token handling
        NotificationCenter.default.post(name: .fcmTokenReceived, object: nil, userInfo: ["token": token])
    }

    
    // MARK: - Push Notification Delegates

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert deviceToken to string (optional)
        let tokenString = deviceToken.reduce("") { $0 + String(format: "%02.2hhx", $1) }

        guard tokenString.count == 64 else {
            print("⚠️ Invalid APNS token length: \(tokenString.count)")
            return
        }

        // Set the APNS token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken

        print("✅ Valid APNS token received: \(tokenString)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }


    private func printError(_ error: Error) {
        print("Error: \(error.localizedDescription)")
    }


    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        let token = fcmToken ?? ""
        print("✅ FCM registration token: \(token)")
        
        // Handle storing/syncing this token
        handleFCMToken(token)
    }

    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Received remote notification: \(userInfo)")

        // Handle your data message here
        // For example, update your UI, fetch data, etc.

        completionHandler(.newData)
    }


 
    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Orientation Handling
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return [.portrait, .landscapeLeft, .landscapeRight]
    }
}


private extension AppDelegate {
    
    func configureFirebaseIfNeeded() {
        guard !isFirebaseConfigured else {
            print("ℹ️ Firebase already configured.")
            return
        }
        
#if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
        AppCheck.setAppCheckProviderFactory(AppCheckDeviceCheckProviderFactory())
#endif
        
        FirebaseApp.configure()
        isFirebaseConfigured = true
        
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        Firestore.firestore().settings.isPersistenceEnabled = false
        
        configureMessaging()
    }
    
    func configureMessaging() {
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
    }
    
    func configureApplicationAppearance() {
        UINavigationBar.appearance().tintColor = .systemOrange
        UITabBar.appearance().tintColor = .systemOrange
    }
    
    func configureAppConfigValues() {
        guard let config = ConfigLoader.loadConfigValues() else {
            print("❌ Could not load configuration values.")
            return
        }
        
        sendgridApiKey = config.SENDGRID_API_KEY
        googleApiKey = config.GoogleApiKey
        googleAppID = config.GoogleAppID
        deviceCheckKeyID = config.DeviceCheckKeyID
        deviceCheckTeamID = config.DeviceCheckTeamID
        googleClientID = FirebaseApp.app()?.options.clientID
        
        appConfig.googleClientID = googleClientID ?? ""
        appConfig.googleApiKey = googleApiKey ?? ""
        appConfig.googleAppID = googleAppID ?? ""
        appConfig.sendgridApiKey = sendgridApiKey ?? "DEFAULT_SENDGRID_API_KEY"
        appConfig.deviceCheckKeyID = deviceCheckKeyID ?? ""
        appConfig.deviceCheckTeamID = deviceCheckTeamID ?? ""
    }
    
    func configureGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("❌ Could not get clientID from Firebase options.")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        print("✅ Google Sign-In configured with client ID: \(clientID)")
    }
    
    
    func configureNotifications(for application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            } else if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
}

