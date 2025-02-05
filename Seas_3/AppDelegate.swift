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
        
        // Firebase configuration
        configureFirebase()
                            
        // Check if Firebase has been configured successfully
        if FirebaseApp.app() != nil {
            // No need to initialize FirestoreManager or PersistenceController here
        } else {
            print("Firebase configuration failed.")
        }
        
        // Third-party SDK initializations
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        // App Check setup
        setupAppCheck()
                
        // Firestore collection creation
        Task {
            do {
                try await createFirestoreCollection()
            } catch {
                print("Error creating Firestore collection: \(error.localizedDescription)")
            }
        }

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


    private func createFirestoreCollection() async throws {
        let collectionsToCheck = [
            "pirateIslands",
            "reviews",
            "matTimes",
            "appDayOfWeeks"
        ]

        for collectionName in collectionsToCheck {
            do {
                let querySnapshot = try await Firestore.firestore().collection(collectionName).getDocuments()
                await self.checkLocalRecordsAndCreateFirestoreRecordsIfNecessary(collectionName: collectionName, querySnapshot: querySnapshot)
            } catch {
                print("Error checking Firestore records: \(error)")
                throw error
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
        
        if let localRecords = try? await PersistenceController.shared.fetchLocalRecords(forCollection: collectionName) {
            print("Local records for \(collectionName): \(localRecords)")
            
            // Query records using both hyphenated and non-hyphenated IDs
            var localRecordsNotInFirestore: [String] = []
            for record in localRecords {
                let recordId = record
                let nonHyphenatedId = recordId.replacingOccurrences(of: "-", with: "")
                let query = Firestore.firestore().collection(collectionName).whereField("id", in: [recordId, nonHyphenatedId])
                do {
                    let querySnapshot = try await query.getDocuments()
                    if querySnapshot.documents.isEmpty {
                        localRecordsNotInFirestore.append(record)
                    }
                } catch {
                    print("Error querying records: \(error)")
                }
            }
            
            print("Local records not in Firestore for \(collectionName):")
            for record in localRecordsNotInFirestore {
                print("Record ID: \(record) (contains hyphens: \(record.contains("-")))")
            }
            
            let localRecordsWithoutHyphens = Set(localRecords.map { $0.replacingOccurrences(of: "-", with: "") })
            _ = firestoreRecords.map { $0.replacingOccurrences(of: "-", with: "") }
            let firestoreRecordsNotInLocal = firestoreRecords.filter { !localRecordsWithoutHyphens.contains($0.replacingOccurrences(of: "-", with: "")) }
            
            
            await syncRecords(localRecords: localRecords, firestoreRecords: firestoreRecords, collectionName: collectionName)

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
                
                // Post a new notification when syncing is completed
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: ["message": "Records have been synced successfully."])
                }
            }
        } else {
            print("No local records found for collection: \(collectionName)")
        }
        
        print("Finished checking local records for collection: \(collectionName)")
    }

    private func uploadLocalRecordsToFirestore(collectionName: String, records: [String]) async {
        // Get a reference to the Firestore collection
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)

        // Loop through each local record
        for record in records {
            // Fetch the entire record from Core Data
            guard let localRecord = try? await PersistenceController.shared.fetchLocalRecord(forCollection: collectionName, recordId: UUID(uuidString: record) ?? UUID()) else {
                print("Error fetching local record \(record) from Core Data (FROM APPDELEGATE-uploadLocalRecordsToFirestore)")
                continue
            }

            // Create a dictionary to hold the record's fields
            var recordData: [String: Any] = [:]

            // Populate the dictionary with the record's fields
            switch collectionName {
            case "pirateIslands":
                guard let pirateIsland = localRecord as? PirateIsland else { continue }
                recordData = [
                    "id": pirateIsland.islandID?.uuidString ?? "", // Convert UUID to string
                    "name": pirateIsland.islandName ?? "",
                    "location": pirateIsland.islandLocation ?? "",
                    "country": pirateIsland.country ?? "",
                    "createdByUserId": pirateIsland.createdByUserId ?? "",
                    "createdTimestamp": pirateIsland.createdTimestamp ?? Date(),
                    "gymWebsite": pirateIsland.gymWebsite?.absoluteString ?? "",
                    "latitude": pirateIsland.latitude,
                    "longitude": pirateIsland.longitude,
                    "lastModifiedByUserId": pirateIsland.lastModifiedByUserId ?? "",
                    "lastModifiedTimestamp": pirateIsland.lastModifiedTimestamp ?? Date()
                ]
            case "reviews":
                guard let review = localRecord as? Review else { continue }
                recordData = [
                    "id": review.reviewID.uuidString, // Convert UUID to string
                    "stars": review.stars,
                    "review": review.review,
                    "createdTimestamp": review.createdTimestamp,
                    "averageStar": review.averageStar
                ]
            case "matTimes":
                guard let matTime = localRecord as? MatTime else { continue }
                recordData = [
                    "id": matTime.id?.uuidString ?? "", // Convert UUID to string
                    "type": matTime.type ?? "",
                    "time": matTime.time ?? "",
                    "gi": matTime.gi,
                    "noGi": matTime.noGi,
                    "openMat": matTime.openMat,
                    "restrictions": matTime.restrictions,
                    "restrictionDescription": matTime.restrictionDescription ?? "",
                    "goodForBeginners": matTime.goodForBeginners,
                    "kids": matTime.kids,
                    "createdTimestamp": matTime.createdTimestamp ?? Date()
                ]
            case "appDayOfWeeks":
                guard let appDayOfWeek = localRecord as? AppDayOfWeek else { continue }
                recordData = [
                    "id": appDayOfWeek.appDayOfWeekID ?? "", // Convert UUID to string
                    "day": appDayOfWeek.day,
                    "name": appDayOfWeek.name ?? "",
                    "createdTimestamp": appDayOfWeek.createdTimestamp ?? Date()
                ]
            // Add other collection types as needed
            default:
                print("Unknown collection name: \(collectionName)")
                continue
            }

            // Get a reference to the Firestore document
            let docRef = collectionRef.document(record)

            // Upload the record to Firestore
            do {
                try await docRef.setData(recordData)
                print("Uploaded local record \(record) to Firestore")
            } catch {
                print("Error uploading local record (FROM APPDELEGATE: uploadLocalRecordsToFirestore) \(record) to Firestore:")
                print("Record ID: \(record)")
                print("Error: \(error.localizedDescription)")
                print("Error type: \(type(of: error))")
            }
        }
    }


    private func syncRecords(localRecords: [String], firestoreRecords: [String], collectionName: String) async {
        // Identify records that exist in Core Data but not in Firestore
        let localRecordsNotInFirestore = localRecords.filter { !firestoreRecords.contains($0) && !firestoreRecords.map { $0.replacingOccurrences(of: "-", with: "") }.contains($0) }

        // Identify records that exist in Firestore but not in Core Data
        let localRecordsWithoutHyphens = Set(localRecords.map { $0.replacingOccurrences(of: "-", with: "") })
        _ = firestoreRecords.map { $0.replacingOccurrences(of: "-", with: "") }
        let firestoreRecordsNotInLocal = firestoreRecords.filter { !localRecordsWithoutHyphens.contains($0.replacingOccurrences(of: "-", with: "")) }
        
        
        // Upload local records to Firestore if they don't exist
        await uploadLocalRecordsToFirestore(collectionName: collectionName, records: localRecordsNotInFirestore)

        // Download Firestore records to Core Data if they don't exist locally
        await downloadFirestoreRecordsToLocal(collectionName: collectionName, records: firestoreRecordsNotInLocal)
    }

    // New function to download Firestore records to Core Data
    private func downloadFirestoreRecordsToLocal(collectionName: String, records: [String]) async {
        // Get a reference to the Core Data context
        let context = PersistenceController.shared.container.viewContext
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)
        
        // Loop through each Firestore record
        for record in records {
            // Get a reference to the Firestore document
            let docRef = collectionRef.document(record)
            
            // Fetch the Firestore document
            do {
                let docSnapshot = try await docRef.getDocument()
                
                // Check if the document exists
                if docSnapshot.exists {
                    // Create a new Core Data object based on the collection name
                    var newRecord: NSManagedObject!
                    switch collectionName {
                    case "pirateIslands":
                        newRecord = PirateIsland(context: context)
                        if let pirateIsland = newRecord as? PirateIsland {
                            pirateIsland.islandID = UUID(uuidString: record)
                            pirateIsland.islandName = docSnapshot.get("name") as? String
                            pirateIsland.islandLocation = docSnapshot.get("location") as? String
                            pirateIsland.country = docSnapshot.get("country") as? String
                            pirateIsland.createdByUserId = docSnapshot.get("createdByUserId") as? String
                            pirateIsland.createdTimestamp = docSnapshot.get("createdTimestamp") as? Date
                            pirateIsland.gymWebsite = docSnapshot.get("gymWebsite") as? URL
                            pirateIsland.latitude = docSnapshot.get("latitude") as? Double ?? 0.0
                            pirateIsland.longitude = docSnapshot.get("longitude") as? Double ?? 0.0
                            pirateIsland.lastModifiedByUserId = docSnapshot.get("lastModifiedByUserId") as? String
                            pirateIsland.lastModifiedTimestamp = docSnapshot.get("lastModifiedTimestamp") as? Date
                        }
                        
                    case "reviews":
                        newRecord = Review(context: context)
                        if let review = newRecord as? Review {
                            review.reviewID = UUID(uuidString: record)!
                            review.stars = (docSnapshot.get("stars") as? Int16)!
                            review.review = (docSnapshot.get("review") as? String)!
                            review.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Date)!
                            review.averageStar = (docSnapshot.get("averageStar") as? Int16)!
                        }
                        
                    case "matTimes":
                        newRecord = MatTime(context: context)
                        if let matTime = newRecord as? MatTime {
                            matTime.id = UUID(uuidString: record)
                            matTime.type = docSnapshot.get("type") as? String
                            matTime.time = docSnapshot.get("time") as? String
                            matTime.gi = docSnapshot.get("gi") as? Bool ?? false
                            matTime.noGi = docSnapshot.get("noGi") as? Bool ?? false
                            matTime.openMat = docSnapshot.get("openMat") as? Bool ?? false
                            matTime.restrictions = docSnapshot.get("restrictions") as? Bool ?? false
                            matTime.restrictionDescription = docSnapshot.get("restrictionDescription") as? String
                            matTime.goodForBeginners = docSnapshot.get("goodForBeginners") as? Bool ?? false
                            matTime.kids = docSnapshot.get("kids") as? Bool ?? false
                            matTime.createdTimestamp = docSnapshot.get("createdTimestamp") as? Date
                        }

                    case "appDayOfWeeks":
                        newRecord = AppDayOfWeek(context: context)
                        if let appDayOfWeek = newRecord as? AppDayOfWeek {
                            appDayOfWeek.appDayOfWeekID = UUID(uuidString: record)?.uuidString
                            appDayOfWeek.day = docSnapshot.get("day") as? String ?? ""
                            appDayOfWeek.name = docSnapshot.get("name") as? String
                            appDayOfWeek.createdTimestamp = docSnapshot.get("createdTimestamp") as? Date
                        }
                        
                    default:
                        print("Unknown collection name: \(collectionName)")
                        return
                    }
                    
                    // Save the new record to Core Data
                    await context.perform {
                        do {
                            try context.save()
                            print("Downloaded Firestore record \(record) to Core Data")
                        } catch {
                            print("Error downloading Firestore record \(record) to Core Data: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("Firestore document does not exist for record: \(record)")
                }
            } catch {
                print("Error fetching Firestore document for record: \(record)")
            }
        }
    }
    
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
