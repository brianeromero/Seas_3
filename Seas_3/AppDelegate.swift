// Apple Frameworks
import UIKit
import SwiftUI
import CoreData
import UserNotifications
import AppTrackingTransparency
import AdSupport
import DeviceCheck

// Firebase
import Firebase
import FirebaseAppCheck
import FirebaseAnalytics
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseFirestore
import FirebaseMessaging

// Google
import GoogleMobileAds
import GoogleSignIn

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
    let persistenceController = PersistenceController.shared
    let appConfig = AppConfig.shared

    var facebookSecret: String?
    var sendgridApiKey: String?
    var googleClientID: String?
    var googleApiKey: String?
    var googleAppID: String?
    var deviceCheckKeyID: String?
    var deviceCheckTeamID: String?

    var isFirebaseConfigured = false

    enum AppCheckTokenError: Error {
        case noTokenReceived
        case invalidToken
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureApplicationAppearance()
        
        // Third-party SDK initializations
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // Firebase configuration
        configureFirebase()
        
        // Initialize PersistenceController after Firebase configuration
        // Configure PersistenceController with Firestore
        PersistenceController.shared.configure(db: Firestore.firestore())

        // App Check setup
        setupAppCheck()
        
        // Firestore collection creation
        createFirestoreCollection()

        // Google Ads configuration
        configureGoogleAds()
        
        // Request IDFA permission
        IDFAHelper.requestIDFAPermission()
        
        // Load configuration values
        loadConfigValues()
        
        // Register for push notifications
        registerForPushNotifications {}

        return true
    }

    
    private func configureApplicationAppearance() {
        UINavigationBar.appearance().tintColor = .systemOrange
        UITabBar.appearance().tintColor = .systemOrange
    }


    private func createFirestoreCollection() {
        let collectionsToCheck = [
            "pirateIslands",
            "reviews",
            "matTimes",
            "appDayOfWeek" // Added AppDayOfWeek to the collections to check
        ]

        
        collectionsToCheck.forEach { collectionName in
            Firestore.firestore().collection(collectionName).getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error checking Firestore records: \(error)")
                    return
                }
                
                Task {
                    await self.checkLocalRecordsAndCreateFirestoreRecordsIfNecessary(collectionName: collectionName, querySnapshot: querySnapshot)
                }
            }
        }
    }

    private func checkLocalRecordsAndCreateFirestoreRecordsIfNecessary(collectionName: String, querySnapshot: QuerySnapshot?) async {
        print("Checking local records for collection: \(collectionName)")
        
        guard let querySnapshot = querySnapshot else {
            print("Error: Query snapshot is nil for collection \(collectionName)")
            return
        }
        
        print("Query snapshot received for collection: \(collectionName)")
        
        let firestoreRecords = querySnapshot.documents.compactMap { $0.documentID }
        print("Firestore records for \(collectionName): \(firestoreRecords)")
        
        do {
            if let localRecords = try await PersistenceController.shared.fetchLocalRecords(forCollection: collectionName) {
                print("Local records for \(collectionName): \(localRecords)")
                
                let localRecordsNotInFirestore = localRecords.filter { !firestoreRecords.contains($0) }
                print("Local records not in Firestore for \(collectionName): \(localRecordsNotInFirestore)")
                
                let firestoreRecordsNotInLocal = firestoreRecords.filter { !localRecords.contains($0) }
                print("Firestore records not in local for \(collectionName): \(firestoreRecordsNotInLocal)")
                
                if !localRecordsNotInFirestore.isEmpty || !firestoreRecordsNotInLocal.isEmpty {
                    print("Records are out of sync for collection: \(collectionName)")
                    
                    // Log before posting to notification center
                    print("Posting ShowToast notification for collection: \(collectionName) with message: You need to sync your records.")
                    
                    // Introduce a small delay before posting the notification
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: ["message": "You need to sync your records."])
                    }
                } else {
                    print("Records are in sync for collection: \(collectionName)")
                }
            } else {
                print("No local records found for collection: \(collectionName)")
            }
        } catch {
            print("Error fetching local records: \(error)")
        }
        
        print("Finished checking local records for collection: \(collectionName)")
    }




    private func uploadLocalRecordsToFirestore(collectionName: String, records: [String]) async {
        // Implement logic to upload local records to Firestore
        // ...
    }



/*    private func shouldCreateRecord(_ localRecord: String, collectionName: String) -> Bool {
        // Add logic to determine if the record should be created
        // For example, you can check if the record is new or has been updated
        // For now, return false to prevent unnecessary records from being created
        return false
    }
*/
    func configureFirebase() {
        guard !isFirebaseConfigured else { return }
        
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif
        
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
        Analytics.setAnalyticsCollectionEnabled(true)
        isFirebaseConfigured = true
        
        // Firestore setup directly here
        Firestore.firestore().settings = FirestoreSettings()
        
        configureFirebaseLogger()
        configureMessaging()
        configureFirestore()
    }


    private func configureFirebaseLogger() {
        FirebaseConfiguration.shared.setLoggerLevel(.debug)
    }

    private func configureMessaging() {
        Messaging.messaging().delegate = self
        Messaging.messaging().isAutoInitEnabled = true
    }

    private func configureFirestore() {
        Firestore.firestore().settings = FirestoreSettings()
    }

    private func setupAppCheck() {
        #if DEBUG
        print("Running in DEBUG mode")
        #else
        let seasAppCheckProviderFactory = SeasAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(seasAppCheckProviderFactory)
        #endif
        
        fetchAppCheckToken()
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
        GADMobileAds.sharedInstance().requestConfiguration.setPublisherFirstPartyIDEnabled(false)
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

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert deviceToken to string
        let token = deviceToken.reduce("") { $0 + String(format: "%02.2hhx", $1) }
        
        // Validate token length (should be 64 characters)
        guard token.count == 64 else {
            print("Invalid APNS token length")
            return
        }
        
        // Set APNS token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        // Log or handle valid token
        print("Valid APNS token received: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        printError(error)
    }

    private func printError(_ error: Error) {
        print("Error: \(error.localizedDescription)")
    }

    private func loadConfigValues() {
        guard let config = ConfigLoader.loadConfigValues() else {
            print("Could not load configuration values.")
            return
        }
        
        // Use optional binding to safely unwrap optionals
        sendgridApiKey = config.SENDGRID_API_KEY
        googleClientID = config.GoogleClientID
        googleApiKey = config.GoogleApiKey
        googleAppID = config.GoogleAppID
        deviceCheckKeyID = config.DeviceCheckKeyID
        deviceCheckTeamID = config.DeviceCheckTeamID

        // Use nil coalescing operator to provide default values
        appConfig.googleClientID = googleClientID ?? ""
        appConfig.googleApiKey = googleApiKey ?? ""
        appConfig.googleAppID = googleAppID ?? ""
        appConfig.sendgridApiKey = sendgridApiKey ?? "DEFAULT_SENDGRID_API_KEY"
        appConfig.deviceCheckKeyID = deviceCheckKeyID ?? ""
        appConfig.deviceCheckTeamID = deviceCheckTeamID ?? ""
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        handleFCMToken(fcmToken ?? "")
    }

    func messaging(_ messaging: Messaging, didReceive message: [String: Any]) {
        print("Message received: \(message)")
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
