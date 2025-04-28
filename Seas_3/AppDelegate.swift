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

        // Configure app appearance early in the app lifecycle
        configureApplicationAppearance()
        
        // Firebase configuration
        configureFirebase()
        
        // Check if Firebase has been configured successfully
        if FirebaseApp.app() != nil {
            // Firebase is successfully configured
        } else {
            print("Firebase configuration failed.")
        }
        
        // Third-party SDK initializations (e.g., Facebook, Ads)
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        configureGoogleAds()

        // Google Sign-In configuration
        configureGoogleSignIn()

        // App Check setup (Firebase App Check, if applicable)
        setupAppCheck()
        
        // Firestore collection creation and downloading records to Core Data
        Task {
            let pirateIslandRecords: [String] = [] // populate with actual records
            let reviewRecords: [String] = [] // populate with actual records
            let matTimeRecords: [String] = [] // populate with actual records
            let appDayOfWeekRecords: [String] = [] // populate with actual records
            
            do {
                try await createFirestoreCollection()
                
                // Download Firestore records to Core Data
                await downloadFirestoreRecordsToLocal(collectionName: "pirateIslands", records: pirateIslandRecords)
                await downloadFirestoreRecordsToLocal(collectionName: "reviews", records: reviewRecords)
                await downloadFirestoreRecordsToLocal(collectionName: "matTimes", records: matTimeRecords)
                await downloadFirestoreRecordsToLocal(collectionName: "AppDayOfWeek", records: appDayOfWeekRecords)
            } catch {
                print("Error creating Firestore collection or downloading records: \(error.localizedDescription)")
            }
        }

        // Request IDFA permission
        IDFAHelper.requestIDFAPermission()
        
        // Load configuration values (can be done after other setups)
        loadConfigValues()
        
        // Register for push notifications
        registerForPushNotifications {}
        
        return true
    }

    
    private func configureApplicationAppearance() {
        UINavigationBar.appearance().tintColor = .systemOrange
        UITabBar.appearance().tintColor = .systemOrange
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

        // Disable Firestore persistence (local cache)
        let settings = Firestore.firestore().settings
        settings.isPersistenceEnabled = false  // Disable local cache if needed
        Firestore.firestore().settings = settings

        // Enable Firestore debug logs
        UserDefaults.standard.setValue(true, forKey: "FIRFirestoreDebugEnabled")
        UserDefaults.standard.setValue(true, forKey: "FIRFirestoreVerboseLoggingEnabled")

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

    
    private func loadConfigValues() {
        print("🔹 Loading configuration values...")

        guard let config = ConfigLoader.loadConfigValues() else {
            print("❌ Could not load configuration values.")
            return
        }

        // Assign values
        sendgridApiKey = config.SENDGRID_API_KEY
        googleClientID = config.GoogleClientID
        googleApiKey = config.GoogleApiKey
        googleAppID = config.GoogleAppID
        deviceCheckKeyID = config.DeviceCheckKeyID
        deviceCheckTeamID = config.DeviceCheckTeamID

        // Log loaded values for debugging
        print("✅ Configuration Loaded:")
        print("   - SendGrid API Key: \(sendgridApiKey ?? "MISSING")")
        print("   - Google Client ID: \(googleClientID ?? "MISSING")")
        print("   - Google API Key: \(googleApiKey ?? "MISSING")")
        print("   - Google App ID: \(googleAppID ?? "MISSING")")
        print("   - DeviceCheck Key ID: \(deviceCheckKeyID ?? "MISSING")")
        print("   - DeviceCheck Team ID: \(deviceCheckTeamID ?? "MISSING")")

        // Assign values with default fallbacks
        appConfig.googleClientID = googleClientID ?? ""
        appConfig.googleApiKey = googleApiKey ?? ""
        appConfig.googleAppID = googleAppID ?? ""
        appConfig.sendgridApiKey = sendgridApiKey ?? "DEFAULT_SENDGRID_API_KEY"
        appConfig.deviceCheckKeyID = deviceCheckKeyID ?? ""
        appConfig.deviceCheckTeamID = deviceCheckTeamID ?? ""

        print("✅ Configuration values set successfully.")
    }

    
    func configureGoogleSignIn() {
        print("🔹 Configuring Google Sign-In...")

        guard let clientID = googleClientID, !clientID.isEmpty else {
            print("❌ Google Client ID is missing or empty.")
            return
        }

        print("✅ Using Google Client ID: \(clientID)")

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        print("✅ Google Sign-In configuration set successfully.")
    }



    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    
    private func createFirestoreCollection() async throws {
        let collectionsToCheck = [
            "pirateIslands",
            "reviews",
            "MatTime",
            "AppDayOfWeek"
        ]

        for collectionName in collectionsToCheck {
            do {
                let querySnapshot = try await Firestore.firestore().collection(collectionName).getDocuments()
                
                if collectionName == "MatTime" || collectionName == "AppDayOfWeek" {
                    if querySnapshot.documents.isEmpty {
                        print("No documents found in collection \(collectionName).")
                    } else {
                        print("Collection \(collectionName) has \(querySnapshot.documents.count) documents.")
                        print("Document IDs in collection \(collectionName): \(querySnapshot.documents.map { $0.documentID })")
                    }
                }
                
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
            await syncRecords(localRecords: [], firestoreRecords: firestoreRecords, collectionName: collectionName)
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
                    "id": review.reviewID.uuidString,
                    "stars": review.stars,
                    "review": review.review,
                    "name": review.userName ?? "Anonymous",
                    "createdTimestamp": review.createdTimestamp,
                    "islandID": review.island?.islandID?.uuidString ?? ""
                ]

                
                
            case "MatTime":
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
                    "createdTimestamp": matTime.createdTimestamp ?? Date(),
                    "appDayOfWeekID": matTime.appDayOfWeek?.appDayOfWeekID ?? "" // Add appDayOfWeekID field
                ]

                
            case "AppDayOfWeek":
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

        // Prioritized download process
        let orderedCollections = ["pirateIslands", "reviews","AppDayOfWeek", "MatTime"]
        for collection in orderedCollections {
            let recordIDs = firestoreRecordsNotInLocal // You can use firestoreRecordsNotInLocal or update this logic as needed
            await downloadFirestoreRecordsToLocal(collectionName: collection, records: recordIDs)
        }
    }


    // New function to download Firestore records to Core Data
    private func downloadFirestoreRecordsToLocal(collectionName: String, records: [String]) async {
        print("Downloading Firestore records to local Core Data for collection: \(collectionName)")

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
                            if let uuid = UUID(uuidString: record) {
                                pirateIsland.islandID = uuid
                            } else {
                                print("Invalid UUID string: \(record)")
                            }
                            pirateIsland.islandName = docSnapshot.get("name") as? String
                            pirateIsland.islandLocation = docSnapshot.get("location") as? String
                            pirateIsland.country = docSnapshot.get("country") as? String
                            pirateIsland.createdByUserId = docSnapshot.get("createdByUserId") as? String
                            pirateIsland.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
                            pirateIsland.gymWebsite = docSnapshot.get("gymWebsite") as? URL
                            pirateIsland.latitude = docSnapshot.get("latitude") as? Double ?? 0.0
                            pirateIsland.longitude = docSnapshot.get("longitude") as? Double ?? 0.0
                            pirateIsland.lastModifiedByUserId = docSnapshot.get("lastModifiedByUserId") as? String
                            pirateIsland.lastModifiedTimestamp = (docSnapshot.get("lastModifiedTimestamp") as? Timestamp)?.dateValue()
                        }

                    case "reviews":
                        newRecord = Review(context: context)
                        
                        if let review = newRecord as? Review {
                            // 🆔 Review ID (from Firestore document ID)
                            if let uuid = UUID(uuidString: record) {
                                review.reviewID = uuid
                            } else {
                                print("Invalid UUID string: \(record)")
                            }

                            // ⭐️ Review content
                            
                            review.stars = docSnapshot.get("stars") as? Int16 ?? 0
                            review.review = docSnapshot.get("review") as? String ?? ""
                            review.userName = docSnapshot.get("userName") as? String ??
                                              docSnapshot.get("name") as? String ?? "Anonymous"
                            review.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue() ?? Date()

                            // 🌴 Link to the correct island
                            if let islandIDString = docSnapshot.get("islandID") as? String,
                               let island = fetchPirateIslandByID(islandIDString) {
                                review.island = island
                            } else {
                                print("Failed to link review to island: \(docSnapshot.get("islandID") ?? "nil")")
                            }
                        }


                        
                    case "MatTime":
                        // Check if the MatTime already exists in Core Data
                        var matTime = fetchMatTimeByID(record)
                        if matTime == nil {
                            matTime = MatTime(context: context)
                            matTime?.id = UUID(uuidString: record)
                        }

                        if let matTime = matTime {
                            matTime.type = docSnapshot.get("type") as? String
                            matTime.time = docSnapshot.get("time") as? String
                            matTime.gi = docSnapshot.get("gi") as? Bool ?? false
                            matTime.noGi = docSnapshot.get("noGi") as? Bool ?? false
                            matTime.openMat = docSnapshot.get("openMat") as? Bool ?? false
                            matTime.restrictions = docSnapshot.get("restrictions") as? Bool ?? false
                            matTime.restrictionDescription = docSnapshot.get("restrictionDescription") as? String
                            matTime.goodForBeginners = docSnapshot.get("goodForBeginners") as? Bool ?? false
                            matTime.kids = docSnapshot.get("kids") as? Bool ?? false
                            matTime.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
                            
                            // Link to AppDayOfWeek
                            if let appDayOfWeekRef = docSnapshot.get("appDayOfWeek") as? DocumentReference {
                                let appDayOfWeekID = appDayOfWeekRef.documentID
                                if let appDayOfWeek = fetchAppDayOfWeekByID(appDayOfWeekID) {
                                    matTime.appDayOfWeek = appDayOfWeek
                                }
                            }
                        }

                    case "AppDayOfWeek":
                        var appDayOfWeek = fetchAppDayOfWeekByID(record)
                        if appDayOfWeek == nil {
                            appDayOfWeek = AppDayOfWeek(context: context)
                        }

                        if let appDayOfWeek = appDayOfWeek {
                            appDayOfWeek.appDayOfWeekID = record
                            appDayOfWeek.day = docSnapshot.get("day") as? String ?? ""  // Non-Optional
                            appDayOfWeek.name = docSnapshot.get("name") as? String
                            appDayOfWeek.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
                            // Get full pIsland map
                            if let pIsland = docSnapshot.get("pIsland") as? [String: Any],
                               let pirateIslandID = pIsland["islandID"] as? String {

                                if let pirateIsland = fetchPirateIslandByID(pirateIslandID) {
                                    appDayOfWeek.pIsland = pirateIsland
                                } else {
                                    // Auto-create PirateIsland from Firestore data
                                    let newIsland = PirateIsland(context: context)

                                    if let uuid = UUID(uuidString: pirateIslandID) {
                                        newIsland.islandID = uuid
                                    } else {
                                        print("Failed to convert islandID string to UUID: \(pirateIslandID)")
                                    }

                                    newIsland.islandName = pIsland["islandName"] as? String
                                    newIsland.islandLocation = pIsland["islandLocation"] as? String
                                    newIsland.country = pIsland["country"] as? String
                                    newIsland.latitude = pIsland["latitude"] as? Double ?? 0
                                    newIsland.longitude = pIsland["longitude"] as? Double ?? 0

                                    appDayOfWeek.pIsland = newIsland
                                    print("Created new PirateIsland from Firestore: \(pirateIslandID)")
                                }
                            }

                            if let matTimesArray = docSnapshot.get("matTimes") as? [String] {
                                for matTimeID in matTimesArray {
                                    if let matTime = fetchMatTimeByID(matTimeID) {
                                        appDayOfWeek.addToMatTimes(matTime)
                                    }
                                }
                            }
                        }


                    default:
                        print("Unknown collection: \(collectionName)")
                        return
                    }

                    // Save to Core Data
                    await context.perform {
                        do {
                            try context.save()
                            print("Successfully synced Firestore \(collectionName) record \(record) to Core Data.")
                        } catch let error {
                            print("Error syncing \(collectionName) record \(record) from Firestore to Core Data: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("Firestore document does not exist for record: \(record)")
                }
            } catch {
                print("Error fetching Firestore document for record: \(record): \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchPirateIslandByID(_ id: String) -> PirateIsland? {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()

        guard let uuid = UUID(uuidString: id) else {
            print("Invalid UUID string: \(id)")
            return nil
        }

        fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching PirateIsland by ID: \(error.localizedDescription)")
            return nil
        }
    }


    private func fetchMatTimeByID(_ id: String) -> MatTime? {
        let fetchRequest: NSFetchRequest<MatTime> = MatTime.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        do {
            let results = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching MatTime by ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Add this method to the appropriate place in your Core Data manager or persistence controller
    private func fetchAppDayOfWeekByID(_ id: String) -> AppDayOfWeek? {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "appDayOfWeekID == %@", id)

        do {
            let results = try context.fetch(fetchRequest)
            return results.first // Return the first match, or nil if none found
        } catch {
            print("Error fetching AppDayOfWeek by ID: \(error.localizedDescription)")
            return nil
        }
    }


    private func syncAppDayOfWeekRecords() async {
        // Fetch Firestore records for "AppDayOfWeek"
        let db = Firestore.firestore()
        let collectionRef = db.collection("AppDayOfWeek")
        do {
            let querySnapshot = try await collectionRef.getDocuments()
            let firestoreRecords = querySnapshot.documents.compactMap { $0.documentID }

            // Fetch local Core Data records for "AppDayOfWeek"
            let localRecords = try? await PersistenceController.shared.fetchLocalRecords(forCollection: "AppDayOfWeek")

            // Identify records that exist in Firestore but not in Core Data
            let localRecordsSet = Set(localRecords ?? [])
            let recordsToDownload = firestoreRecords.filter { !localRecordsSet.contains($0) }

            // Download Firestore records to Core Data
            await downloadAppDayOfWeekRecords(records: recordsToDownload)
        } catch {
            print("Error syncing appDayOfWeek records: \(error.localizedDescription)")
        }
    }

    private func downloadAppDayOfWeekRecords(records: [String]) async {
        // Get a reference to the Core Data context
        let context = PersistenceController.shared.container.viewContext
        let db = Firestore.firestore()
        let collectionRef = db.collection("AppDayOfWeek")

        // Loop through each record to download
        for record in records {
            // Get a reference to the Firestore document
            let docRef = collectionRef.document(record)

            // Fetch the Firestore document
            do {
                let docSnapshot = try await docRef.getDocument()

                // Check if the document exists
                if docSnapshot.exists {
                    // Create a new Core Data object
                    let newRecord = AppDayOfWeek(context: context)
                    newRecord.appDayOfWeekID = record
                    newRecord.day = docSnapshot.get("day") as? String ?? ""
                    newRecord.name = docSnapshot.get("name") as? String
                    newRecord.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()

                    // Save the new record to Core Data
                    await context.perform {
                        do {
                            try context.save()
                            print("Downloaded appDayOfWeek record \(record) to Core Data")
                        } catch let error {
                            print("Error downloading appDayOfWeek record \(record) to Core Data: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("Firestore document does not exist for record: \(record)")
                }
            } catch {
                print("Error fetching Firestore document for record: \(record): \(error.localizedDescription)")
            }
        }
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
