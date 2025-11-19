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

import os.log // Assuming you're using os_log



// AdServices
import AdServices


class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Properties
    var authStateDidChangeListenerHandle: AuthStateDidChangeListenerHandle?

    // App-wide shared instances - These will be passed to Mat_FinderApp for environment injection
    let appState = AppState()
    lazy var persistenceController = PersistenceController.shared
    lazy var firestoreManager = FirestoreManager.shared
    
    // authenticationState can be initialized here as it doesn't directly depend on Firebase
    let authenticationState: AuthenticationState
    let appConfig = AppConfig.shared

    // ViewModels - Make these implicitly unwrapped optionals (`!`) or optionals (`?`)
    // and initialize them *after* Firebase is configured in didFinishLaunchingWithOptions.
    var authViewModel: AuthViewModel!
    var pirateIslandViewModel: PirateIslandViewModel!
    var profileViewModel: ProfileViewModel! // Will be initialized after Firebase config


    // Config values - Keep as they are, for internal AppDelegate use
    var facebookSecret: String?
    var sendgridApiKey: String?
    var googleClientID: String?
    var googleApiKey: String?
    var googleAppID: String?
    var deviceCheckKeyID: String?
    var deviceCheckTeamID: String?

    var isFirebaseConfigured = false // Controls AppRootView's conditional content

    enum AppCheckTokenError: Error {
        case noTokenReceived, invalidToken
    }

    // Static shared instance for convenience, though for environment objects, passing directly is preferred.
    static var shared: AppDelegate {
        // You might want to guard this more safely if the app delegate isn't always available
        // in certain contexts, but for most app-level access it's fine.
        UIApplication.shared.delegate as! AppDelegate
    }

    // MARK: - Initializer for AppDelegate
    // Only initialize properties that *do not* directly depend on Firebase here.
    override init() {
        self.authenticationState = AuthenticationState(hashPassword: HashPassword(), validator: EmailValidator()) // Assuming EmailValidator is your default
        super.init()
    }


    // MARK: - Application Lifecycle
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ✅ 0. Start Network Monitoring immediately
        _ = NetworkMonitor.shared
        print("🌐 NetworkMonitor initialized and started.")
        print("""
        🔍 [AppDelegate] NetworkMonitor initial state:
        - isConnected: \(NetworkMonitor.shared.isConnected)
        - currentPath: \(String(describing: NetworkMonitor.shared.currentPath))
        - currentStatus: \(String(describing: NetworkMonitor.shared.currentPath?.status))
        """)

        // ✅ Add delayed recheck (2 seconds later)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("""
            🕓 [AppDelegate] Delayed NetworkMonitor check (2s later):
            - isConnected: \(NetworkMonitor.shared.isConnected)
            - currentPath: \(String(describing: NetworkMonitor.shared.currentPath))
            """)
        }

        // ✅ 1. Configure Firebase & App Check FIRST
        configureFirebaseIfNeeded() // This should set `isFirebaseConfigured = true` once done
        print("Current user: \(Auth.auth().currentUser?.uid ?? "nil")")

        // ✅ 2. Initialize ViewModels that depend on Firebase *after* Firebase is configured
        AuthViewModel._shared = AuthViewModel(
            managedObjectContext: PersistenceController.shared.container.viewContext,
            emailManager: UnifiedEmailManager.shared,
            authenticationState: self.authenticationState
        )
        self.authViewModel = AuthViewModel.shared

        self.pirateIslandViewModel = PirateIslandViewModel(persistenceController: PersistenceController.shared)
        self.profileViewModel = ProfileViewModel(
            viewContext: PersistenceController.shared.container.viewContext,
            authViewModel: self.authViewModel
        )

        // ✅ 3. Facebook SDK (after Firebase)
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // ✅ 4. Optional Debug flag
        UserDefaults.standard.set(true, forKey: "AppAuthDebug")

        // ✅ 5. App-specific config/setup
        configureAppConfigValues()
        configureApplicationAppearance()
        configureGoogleSignIn()
        configureNotifications(for: application)
        configureGoogleAds()

        
        // ✅ 6. Reactive network listener
        NotificationCenter.default.addObserver(forName: .networkStatusChanged, object: nil, queue: .main) { [weak self] _ in
            Task {
                guard self != nil else { return }

                if NetworkMonitor.shared.isConnected {
                    // ✅ Only sync if a user is signed in
                    if Auth.auth().currentUser != nil {
                        print("🌐 Network restored — resuming pending Firestore sync")
                        await FirestoreSyncCoordinator.shared.startAppSync()
                    } else {
                        print("🌐 Network restored — no user signed in, skipping sync")
                    }
                }
            }
        }


        // ✅ 7. Defer Keychain test to avoid premature access
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testKeychainAccessGroup()
        }

        // ✅ 8. IDFA request — delayed to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task {
                await IDFAHelper.requestIDFAPermission()
            }
        }

        // ✅ 9. Firebase Auth State Listener (final setup)
        authStateDidChangeListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }

            print("Current user inside listener: \(user?.uid ?? "nil")")

            if let user = user {
                print("✅ Firebase User signed in: \(user.email ?? "N/A") (UID: \(user.uid))")
                self.authViewModel.userSession = user
                self.authenticationState.isAuthenticated = true
                self.authenticationState.isLoggedIn = true

                // 🔹 Trigger Firestore sync safely (single source of truth)
                Task {
                    await FirestoreSyncCoordinator.shared.startAppSync()
                }

            } else {
                print("❌ Firebase No user signed in")
                self.authViewModel.userSession = nil
                self.authenticationState.isAuthenticated = false
                self.authenticationState.isLoggedIn = false
                self.authenticationState.navigateToAdminMenu = false
                print("DEBUG: authenticationState.isAuthenticated set to \(self.authenticationState.isAuthenticated)")
            }
        }

        // 🔟 Start location services
        configureLocationServices()

        // Debug: confirm Google Ads key
        print("GADApplicationIdentifier: \(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") ?? "❌ missing")")

        return true
    }



    func applicationWillTerminate(_ application: UIApplication) {
        if let handle = authStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    
    // MARK: - Location Services
    private func configureLocationServices() {
        print("🧭 Starting UserLocationMapViewModel location services...")
        UserLocationMapViewModel.shared.startLocationServices()
    }
    
    func testKeychainAccessGroup() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "testAccount",
            kSecAttrService as String: "testService",
            kSecAttrAccessGroup as String: "com.google.iid",
            kSecReturnAttributes as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            print("✅ Access group is accessible: \(String(describing: result))")
        case errSecItemNotFound:
            print("🔍 Access group is available, item not found — that’s okay.")
        case errSecDuplicateItem:
            print("⚠️ Duplicate item found in Keychain.")
        case errSecAuthFailed:
            print("🔒 Authentication failed for Keychain access.")
        case errSecInteractionNotAllowed:
            print("🚫 Interaction with Keychain is not allowed (e.g., device locked).")
        case -34018:
            print("🔑 Unknown error, possibly related to entitlements or access rights.")
        default:
            print("❌ Keychain access failed with status: \(status). Check Apple’s documentation for more details.")
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
        let adsInstance = MobileAds.shared

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

    private func configureFirebaseIfNeeded() {
        print("🔧 Configuring Firebase...")

        guard !isFirebaseConfigured else {
            print("ℹ️ Firebase already configured.")
            return
        }

        // ------------------------------
        // App Check configuration
        // ------------------------------
        #if targetEnvironment(simulator)
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        print("ℹ️ App Check: Using Debug Provider (Simulator)")

        #elseif DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        print("ℹ️ App Check: Using Debug Provider (Debug build)")

        #else
        // ✅ Production builds
        if #available(iOS 11.0, *) {
            // DeviceCheck is more broadly supported
            AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
            print("ℹ️ App Check: Using DeviceCheck (Production)")
        } else {
            print("⚠️ DeviceCheck not available on this iOS version")
        }
        #endif

        // ------------------------------
        // Firebase initialization
        // ------------------------------
        FirebaseApp.configure()
        print("✅ Firebase configured.")

        isFirebaseConfigured = true
        NotificationCenter.default.post(name: .firebaseConfigured, object: nil)

        configureMessaging()

        // ------------------------------
        // Debug: log Firebase plist values
        // ------------------------------
        #if DEBUG
        if let app = FirebaseApp.app() {
            let options = app.options
            print("🔍 GOOGLE_APP_ID: \(options.googleAppID)")                 // non-optional
            print("🔍 CLIENT_ID: \(options.clientID ?? "nil")")               // optional
            print("🔍 API_KEY: \(options.apiKey ?? "nil")")                   // optional
            print("🔍 PROJECT_ID: \(options.projectID ?? "nil")")             // optional
            print("🔍 STORAGE_BUCKET: \(options.storageBucket ?? "nil")")     // optional
            print("🔍 DATABASE_URL: \(options.databaseURL ?? "nil")")         // optional
            print("🔍 GCM_SENDER_ID: \(options.gcmSenderID)")                 // non-optional
        }
        #endif

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
