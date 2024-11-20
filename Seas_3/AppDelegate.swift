import UIKit
import Firebase
import FirebaseAppCheck
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import GoogleMobileAds
import GoogleSignIn
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
    
    let persistenceController = PersistenceController.shared
    let appConfig = AppConfig.shared
    
    enum AppCheckTokenError: Error {
        case noTokenReceived
        case invalidToken
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureFirebase()
        configureAppCheck()
        configureAppearance()
        configureGoogleAds()
        requestIDFAPermission()
        loadConfigValues()
        registerForPushNotifications()
        
        return true
    }
    
    // MARK: - Firebase Configuration
    
    private func configureFirebase() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            FirebaseConfiguration.shared.setLoggerLevel(.debug)
            
            let settings = FirestoreSettings()
            Firestore.firestore().settings = settings
            
            Messaging.messaging().delegate = self
            Messaging.messaging().isAutoInitEnabled = true
            Analytics.setAnalyticsCollectionEnabled(true)
        } else {
            print("Firebase already configured")
        }
    }
    
    // MARK: - App Check Configuration
    
    private func configureAppCheck() {
        let appCheckFactory = SeasAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(appCheckFactory)
        fetchAppCheckToken()
    }
    
    // MARK: - Helper Functions
    
    private func configureAppearance() {
        UINavigationBar.appearance().tintColor = .systemOrange
        UITabBar.appearance().tintColor = .systemOrange
    }
    
    private func configureGoogleAds() {
        GADMobileAds.sharedInstance().requestConfiguration.setPublisherFirstPartyIDEnabled(false)
    }
    
    private func requestIDFAPermission() {
        IDFAHelper.requestIDFAPermission()
    }
    
    private func loadConfigValues() {
        guard let config = ConfigLoader.loadConfigValues() else {
            print("Could not load configuration values.")
            return
        }
        
        appConfig.googleClientID = config.GoogleClientID
        appConfig.googleApiKey = config.GoogleApiKey
        appConfig.googleAppID = config.GoogleAppID
        appConfig.sendgridApiKey = config.SENDGRID_API_KEY
        appConfig.deviceCheckKeyID = config.DeviceCheckKeyID
        appConfig.deviceCheckTeamID = config.DeviceCheckTeamID
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
    
    private func fetchAppCheckToken() {
        let appCheck = AppCheck.appCheck()
        appCheck.token(forcingRefresh: true) { [weak self] (appCheckToken: AppCheckToken?, error: Error?) in
            guard self != nil else { return }
            
            if let error = error {
                print("Error fetching App Check token: \(error.localizedDescription)")
                self?.handleAppCheckTokenError(error)
            } else if let appCheckToken = appCheckToken {
                print("App Check token received: \(appCheckToken.token)")
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
}
