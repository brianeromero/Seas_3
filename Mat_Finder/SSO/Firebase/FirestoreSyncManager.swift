//
//  FirestoreSyncManager.swift
//  Mat_Finder
//
//  Created by Brian Romero on 5/23/25.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreData

class FirestoreSyncManager {
    static let shared = FirestoreSyncManager()
    
    func syncInitialFirestoreData() async {
        guard Auth.auth().currentUser != nil else {
            print("❌ No user is signed in. Firestore access is restricted.")
            return
        }

        do {
            try await createFirestoreCollection() // This creates/checks collections
            
            let db = Firestore.firestore()
            
            // PirateIslands
            let pirateIslandSnapshot = try await db.collection("pirateIslands").getDocuments()
            let pirateIslandFirestoreIDs = pirateIslandSnapshot.documents.map { $0.documentID }
            await downloadFirestoreRecordsToLocal(collectionName: "pirateIslands", records: pirateIslandFirestoreIDs)
            
            // Reviews
            let reviewsSnapshot = try await db.collection("reviews").getDocuments()
            let reviewsFirestoreIDs = reviewsSnapshot.documents.map { $0.documentID }
            await downloadFirestoreRecordsToLocal(collectionName: "reviews", records: reviewsFirestoreIDs)
            
            // AppDayOfWeek
            let appDayOfWeekSnapshot = try await db.collection("AppDayOfWeek").getDocuments()
            let appDayOfWeekFirestoreIDs = appDayOfWeekSnapshot.documents.map { $0.documentID }
            await downloadFirestoreRecordsToLocal(collectionName: "AppDayOfWeek", records: appDayOfWeekFirestoreIDs)
            
            // MatTime
            let matTimesSnapshot = try await db.collection("MatTime").getDocuments()
            let matTimesFirestoreIDs = matTimesSnapshot.documents.map { $0.documentID }
            await downloadFirestoreRecordsToLocal(collectionName: "MatTime", records: matTimesFirestoreIDs)
            
            print("✅ Initial Firestore sync complete")
            
        } catch {
            print("❌ Firestore sync error: \(error.localizedDescription)")
        }
    }

    
    private func createFirestoreCollection() async throws {
        let collectionsToCheck = [
            "pirateIslands",
            "reviews",
            "AppDayOfWeek", // ⬅️ AppDayOfWeek must come before MatTime
            "MatTime"
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
        // 👇 Add this right at the top
        let syncID = UUID().uuidString.prefix(8)
        print("🚀 [SyncManager:\(syncID)] Starting sync for \(collectionName)")
        
        print("🚀 [SyncManager:\(syncID)] Initiating record check for collection: \(collectionName)")
        
        
        // ✅ Step 1: Check for network connection before doing anything
        print("""
        🌐 [SyncManager:\(syncID)] Checking network status before sync:
        - isConnected: \(NetworkMonitor.shared.isConnected)
        - currentPath: \(String(describing: NetworkMonitor.shared.currentPath))
        - currentStatus: \(String(describing: NetworkMonitor.shared.currentPath?.status))
        - hasShownNoInternetToast: \(Mirror(reflecting: NetworkMonitor.shared).children.first { $0.label == "hasShownNoInternetToast" }?.value ?? "N/A")
        """)

        guard NetworkMonitor.shared.isConnected else {
            print("""
            ⚠️ [SyncManager:\(syncID)] NetworkMonitor reported offline at \(Date()).
            Current path status: \(NetworkMonitor.shared.currentPath?.status ?? .requiresConnection)
            🔕 Firestore sync for \(collectionName) skipped.
            """)

            // Optional: trigger a visible toast here for debugging
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .showToast,
                    object: nil,
                    userInfo: [
                        "message": "Offline mode — skipping \(collectionName) sync.",
                        "type": ToastView.ToastType.info.rawValue
                    ]
                )
                print("📡 [SyncManager:\(syncID)] Posted temporary offline toast.")
            }
            return
        }
        
        // ✅ Step 2: Continue if querySnapshot is valid
        guard let querySnapshot = querySnapshot else {
            print("❌ [SyncManager] Error: Query snapshot is nil for collection \(collectionName). Cannot proceed with record checking.")
            return
        }
        
        print("✅ [SyncManager] Query snapshot successfully received for collection: \(collectionName)")
        
        let firestoreRecords = querySnapshot.documents.compactMap { $0.documentID }
        print("📊 [SyncManager] Firestore records for \(collectionName) (count: \(firestoreRecords.count)): \(firestoreRecords.prefix(5))\(firestoreRecords.count > 5 ? "... (and \(firestoreRecords.count - 5) more)" : "")")
        
        do {
            if let localRecords = try await PersistenceController.shared.fetchLocalRecords(forCollection: collectionName) {
                print("💾 [SyncManager] Local records for \(collectionName) (count: \(localRecords.count)): \(localRecords.prefix(5))\(localRecords.count > 5 ? "... (and \(localRecords.count - 5) more)" : "")")
                
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
                        print("⚠️ [SyncManager] Error querying Firestore for local record \(record): \(error.localizedDescription)")
                    }
                }
                
                print("🔍 [SyncManager] Local records not found in Firestore for \(collectionName) (count: \(localRecordsNotInFirestore.count)): \(localRecordsNotInFirestore.prefix(5))\(localRecordsNotInFirestore.count > 5 ? "... (and \(localRecordsNotInFirestore.count - 5) more)" : "")")
                
                let localRecordsWithoutHyphens = Set(localRecords.map { $0.replacingOccurrences(of: "-", with: "") })
                let firestoreRecordsNotInLocal = firestoreRecords.filter { !localRecordsWithoutHyphens.contains($0.replacingOccurrences(of: "-", with: "")) }
                print("🔍 [SyncManager] Firestore records not found locally for \(collectionName) (count: \(firestoreRecordsNotInLocal.count)): \(firestoreRecordsNotInLocal.prefix(5))\(firestoreRecordsNotInLocal.count > 5 ? "... (and \(firestoreRecordsNotInLocal.count - 5) more)" : "")")
                
                await syncRecords(localRecords: localRecords, firestoreRecords: firestoreRecords, collectionName: collectionName)
                print("🔄 [SyncManager] `syncRecords` function completed for collection: \(collectionName)")
                
                if !localRecordsNotInFirestore.isEmpty || !firestoreRecordsNotInLocal.isEmpty {
                    print("🚨 [SyncManager] Records are out of sync for collection: \(collectionName). Initiating 'You need to sync your records' toast.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                            "message": "You need to sync your records.",
                            "type": ToastView.ToastType.error.rawValue
                        ])
                        print("📧 [SyncManager] Posted 'ShowToast' notification (error type) for \(collectionName).")
                    }
                } else {
                    print("🎉 [SyncManager] Records are in sync for collection: \(collectionName). Initiating 'Records have been synced successfully' toast.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                            "message": "Records have been synced successfully.",
                            "type": ToastView.ToastType.success.rawValue
                        ])
                        print("📧 [SyncManager] Posted 'ShowToast' notification (success type) for \(collectionName).")
                    }
                }
            } else {
                print("⚠️ [SyncManager] No local records found for collection: \(collectionName) (or error fetching them). Proceeding to sync from Firestore.")
                await syncRecords(localRecords: [], firestoreRecords: firestoreRecords, collectionName: collectionName)
                print("🔄 [SyncManager] `syncRecords` function completed for collection: \(collectionName) (no local records case).")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                        "message": "Local data initialized from cloud.",
                        "type": ToastView.ToastType.info.rawValue
                    ])
                    print("📧 [SyncManager] Posted 'ShowToast' notification (info type - local init) for \(collectionName).")
                }
            }
        } catch {
            print("❌ [SyncManager] Critical error during local record fetch for \(collectionName): \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                    "message": "Error accessing local data: \(error.localizedDescription)",
                    "type": ToastView.ToastType.error.rawValue
                ])
                print("📧 [SyncManager] Posted 'ShowToast' notification (critical error type) for \(collectionName).")
            }
        }
        
        print("🏁 [SyncManager] Finished checking local records for collection: \(collectionName)")
    }
    
    
    
    @MainActor
    private func uploadLocalRecordsToFirestore(collectionName: String, records: [String]) async {
        // Get a reference to the Firestore collection
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)
        
        // Loop through each local record
        for record in records {
            // Fetch the entire record from Core Data
            // The underlying fetchLocalRecord is now also protected by @MainActor,
            // and since this function is @MainActor, this call is safe.
            guard let localRecord = try?  PersistenceController.shared.fetchLocalRecord(forCollection: collectionName, recordId: UUID(uuidString: record) ?? UUID()) else {
                print("Error fetching local record \(record) from Core Data (FROM APPDELEGATE-uploadLocalRecordsToFirestore)")
                continue
            }
            
            // Create a dictionary to hold the record's fields
            var recordData: [String: Any] = [:]
            
            // ⚠️ Core Data property access is now SAFE because the entire function is on the Main Actor
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
                // CRASH POINT WAS HERE, when accessing review properties off-thread
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
            
            // Upload the record to Firestore (Network call is not restricted to main thread)
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
        
        // DOWNLOAD: Pass only the records relevant to the current collectionName
        await downloadFirestoreRecordsToLocal(collectionName: collectionName, records: firestoreRecordsNotInLocal)
    }
    
    // MARK: - Main download function
    private func downloadFirestoreRecordsToLocal(collectionName: String, records: [String]) async {
        print("Downloading Firestore records to local Core Data for collection: \(collectionName)")
        
        if !records.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                    "message": "Downloading \(records.count) \(collectionName) from cloud...",
                    "type": ToastView.ToastType.info.rawValue
                ])
                print("📧 [SyncManager] Posted 'ShowToast' notification for \(collectionName) start.")
            }
        }
        
        let context = await PersistenceController.shared.container.newBackgroundContext()
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)
        
        var downloadedCount = 0
        var errorCount = 0
        
        for record in records {
            let docRef = collectionRef.document(record)
            
            do {
                let docSnapshot = try await docRef.getDocument()
                
                guard docSnapshot.exists else {
                    print("❌ Firestore document does not exist for record: \(record). Skipping.")
                    errorCount += 1
                    continue
                }
                
                print("🔵 Firestore data for \(collectionName) record \(record): \(docSnapshot.data() ?? [:])")
                
                // Capture only the data the closure needs
                let snapshot = docSnapshot
                let collection = collectionName
                
                await context.perform {
                    do {
                        switch collection {
                        case "pirateIslands":
                            try Self.syncPirateIslandStatic(docSnapshot: snapshot, context: context)
                        case "reviews":
                            try Self.syncReviewStatic(docSnapshot: snapshot, context: context)
                        case "MatTime":
                            try Self.syncMatTimeStatic(docSnapshot: snapshot, context: context)
                        case "AppDayOfWeek":
                            try Self.syncAppDayOfWeekStatic(docSnapshot: snapshot, context: context)
                        default:
                            print("❌ Unknown collection: \(collection)")
                            errorCount += 1
                        }
                        
                        try context.save()
                        downloadedCount += 1
                        print("✅ Synced \(collection) record \(record) to Core Data.")
                    } catch {
                        context.rollback()
                        print("❌ Error syncing \(collection) record \(record): \(error)")
                        errorCount += 1
                    }
                }

                
                
            } catch {
                print("❌ Error fetching Firestore document for \(collectionName) record \(record): \(error.localizedDescription)")
                errorCount += 1
            }
        } // end for record in records
        
        // Final toast
        if !records.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let message: String
                let type: String
                
                if errorCount == 0 {
                    message = "Successfully downloaded \(downloadedCount) \(collectionName) records."
                    type = ToastView.ToastType.success.rawValue
                } else if downloadedCount > 0 {
                    message = "Downloaded \(downloadedCount) \(collectionName) records, \(errorCount) failed."
                    type = ToastView.ToastType.info.rawValue
                } else {
                    message = "Failed to download any \(collectionName) records. Check logs."
                    type = ToastView.ToastType.error.rawValue
                }
                
                NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                    "message": message,
                    "type": type
                ])
            }
        }
    }
    
    
    // MARK: - Static helpers for Firestore sync
    
    // ---------------------------
    // PirateIsland
    // ---------------------------
    private static func syncPirateIslandStatic(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        
        guard let uuid = UUID(uuidString: docSnapshot.documentID) else {
            print("Invalid UUID string: \(docSnapshot.documentID)")
            return
        }
        
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1
        
        var pirateIsland: PirateIsland?
        
        do {
            pirateIsland = try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching PirateIsland by ID: \(error.localizedDescription)")
        }
        
        if pirateIsland == nil {
            pirateIsland = PirateIsland(context: context)
            pirateIsland?.islandID = uuid
            print("🟡 Creating new PirateIsland with ID: \(docSnapshot.documentID)")
        } else {
            print("🟢 Updating existing PirateIsland with ID: \(docSnapshot.documentID)")
        }
        
        if let pi = pirateIsland {
            pi.islandName = docSnapshot.get("name") as? String
            pi.islandLocation = docSnapshot.get("location") as? String
            pi.country = docSnapshot.get("country") as? String
            pi.createdByUserId = docSnapshot.get("createdByUserId") as? String
            pi.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
            
            if let urlString = docSnapshot.get("gymWebsite") as? String {
                pi.gymWebsite = URL(string: urlString)
            }
            
            pi.latitude = docSnapshot.get("latitude") as? Double ?? 0.0
            pi.longitude = docSnapshot.get("longitude") as? Double ?? 0.0
            pi.lastModifiedByUserId = docSnapshot.get("lastModifiedByUserId") as? String
            pi.lastModifiedTimestamp = (docSnapshot.get("lastModifiedTimestamp") as? Timestamp)?.dateValue()
        }
    }
    
    // ---------------------------
    // Review
    // ---------------------------
    private static func syncReviewStatic(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        let fetchRequest = Review.fetchRequest() as! NSFetchRequest<Review>
        
        guard let uuid = UUID(uuidString: docSnapshot.documentID) else {
            print("Invalid UUID string for Review: \(docSnapshot.documentID)")
            return
        }
        
        fetchRequest.predicate = NSPredicate(format: "reviewID == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1
        
        var review: Review?
        
        do {
            review = try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching Review by ID: \(error.localizedDescription)")
        }
        
        if review == nil {
            review = Review(context: context)
            review?.reviewID = uuid
            print("🟡 Creating new Review with ID: \(docSnapshot.documentID)")
        } else {
            print("🟢 Updating existing Review with ID: \(docSnapshot.documentID)")
        }
        
        if let r = review {
            r.stars = docSnapshot.get("stars") as? Int16 ?? 0
            r.review = docSnapshot.get("review") as? String ?? ""
            r.userName = docSnapshot.get("userName") as? String ?? docSnapshot.get("name") as? String ?? "Anonymous"
            r.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue() ?? Date()
            
            if let islandIDString = docSnapshot.get("islandID") as? String {
                let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                if let uuid = UUID(uuidString: islandIDString) {
                    fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
                    fetchRequest.fetchLimit = 1
                    if let island = try? context.fetch(fetchRequest).first {
                        r.island = island
                    }
                }
            }
        }
    }
    
    // ---------------------------
    // MatTime
    // ---------------------------
    private static func syncMatTimeStatic(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<MatTime> = MatTime.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", docSnapshot.documentID)
        fetchRequest.fetchLimit = 1
        
        var matTime: MatTime?
        
        do {
            matTime = try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching MatTime by ID: \(error.localizedDescription)")
        }
        
        if matTime == nil {
            matTime = MatTime(context: context)
            if let uuid = UUID(uuidString: docSnapshot.documentID) {
                matTime?.id = uuid
                print("🟡 Creating new MatTime with ID: \(docSnapshot.documentID)")
            }
        } else {
            print("🟢 Updating existing MatTime with ID: \(docSnapshot.documentID)")
        }
        
        if let mt = matTime {
            mt.type = docSnapshot.get("type") as? String
            mt.time = docSnapshot.get("time") as? String
            mt.gi = docSnapshot.get("gi") as? Bool ?? false
            mt.noGi = docSnapshot.get("noGi") as? Bool ?? false
            mt.openMat = docSnapshot.get("openMat") as? Bool ?? false
            mt.restrictions = docSnapshot.get("restrictions") as? Bool ?? false
            mt.restrictionDescription = docSnapshot.get("restrictionDescription") as? String
            mt.goodForBeginners = docSnapshot.get("goodForBeginners") as? Bool ?? false
            mt.kids = docSnapshot.get("kids") as? Bool ?? false
            mt.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
            
            if let appDayOfWeekRef = docSnapshot.get("appDayOfWeek") as? DocumentReference {
                let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "appDayOfWeekID == %@", appDayOfWeekRef.documentID)
                fetchRequest.fetchLimit = 1
                if let appDayOfWeek = try? context.fetch(fetchRequest).first {
                    mt.appDayOfWeek = appDayOfWeek
                }
            }
        }
    }
    
    // ---------------------------
    // AppDayOfWeek
    // ---------------------------
    private static func syncAppDayOfWeekStatic(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "appDayOfWeekID == %@", docSnapshot.documentID)
        fetchRequest.fetchLimit = 1
        
        var ado: AppDayOfWeek?
        
        do {
            ado = try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching AppDayOfWeek by ID: \(error.localizedDescription)")
        }
        
        if ado == nil {
            ado = AppDayOfWeek(context: context)
            ado?.appDayOfWeekID = docSnapshot.documentID
            print("🟡 Creating new AppDayOfWeek with ID: \(docSnapshot.documentID)")
        } else {
            print("🟢 Updating existing AppDayOfWeek with ID: \(docSnapshot.documentID)")
        }
        
        if let ado = ado {
            ado.day = docSnapshot.get("day") as? String ?? ""
            ado.name = docSnapshot.get("name") as? String
            ado.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
            
            // Link to PirateIsland
            if let pIslandData = docSnapshot.get("pIsland") as? [String: Any],
               let pirateIslandID = pIslandData["islandID"] as? String {
                let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                if let uuid = UUID(uuidString: pirateIslandID) {
                    fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
                    fetchRequest.fetchLimit = 1
                    if let pirateIsland = try? context.fetch(fetchRequest).first {
                        ado.pIsland = pirateIsland
                    }
                }
            }
            
            // Link MatTimes
            if let matTimesArray = docSnapshot.get("matTimes") as? [String] {
                for matTimeID in matTimesArray {
                    let fetchRequest: NSFetchRequest<MatTime> = MatTime.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", matTimeID)
                    fetchRequest.fetchLimit = 1
                    if let matTime = try? context.fetch(fetchRequest).first {
                        ado.addToMatTimes(matTime)
                    }
                }
            }
        }
    }
    
    
    
    
    // MARK: - Helper functions
    
    private func syncPirateIsland(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var pirateIsland = fetchPirateIslandByID(docSnapshot.documentID, in: context)
        if pirateIsland == nil {
            pirateIsland = PirateIsland(context: context)
            pirateIsland?.islandID = UUID(uuidString: docSnapshot.documentID)
            print("🟡 Creating new PirateIsland with ID: \(docSnapshot.documentID)")
        } else {
            print("🟢 Updating existing PirateIsland with ID: \(docSnapshot.documentID)")
        }
        
        if let pi = pirateIsland {
            pi.islandName = docSnapshot.get("name") as? String
            pi.islandLocation = docSnapshot.get("location") as? String
            pi.country = docSnapshot.get("country") as? String
            pi.createdByUserId = docSnapshot.get("createdByUserId") as? String
            pi.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
            if let urlString = docSnapshot.get("gymWebsite") as? String {
                pi.gymWebsite = URL(string: urlString)
            }
            pi.latitude = docSnapshot.get("latitude") as? Double ?? 0.0
            pi.longitude = docSnapshot.get("longitude") as? Double ?? 0.0
            pi.lastModifiedByUserId = docSnapshot.get("lastModifiedByUserId") as? String
            pi.lastModifiedTimestamp = (docSnapshot.get("lastModifiedTimestamp") as? Timestamp)?.dateValue()
        }
    }
    
    
    private func syncReview(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var review = fetchReviewByID(docSnapshot.documentID, in: context)
        if review == nil {
            review = Review(context: context)
            if let uuid = UUID(uuidString: docSnapshot.documentID) {
                review?.reviewID = uuid
            } else {
                print("❌ Invalid UUID for Review: \(docSnapshot.documentID)")
            }
            print("🟡 Creating new Review with ID: \(docSnapshot.documentID)")
        } else {
            print("🟢 Updating existing Review with ID: \(docSnapshot.documentID)")
        }
        
        if let r = review {
            r.stars = docSnapshot.get("stars") as? Int16 ?? 0
            r.review = docSnapshot.get("review") as? String ?? ""
            r.userName = docSnapshot.get("userName") as? String ?? docSnapshot.get("name") as? String ?? "Anonymous"
            r.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue() ?? Date()
            
            if let islandIDString = docSnapshot.get("islandID") as? String,
               let island = fetchPirateIslandByID(islandIDString, in: context) {
                r.island = island
            }
        }
    }

    
    private func syncMatTime(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var matTime = fetchMatTimeByID(docSnapshot.documentID, in: context)
        if matTime == nil {
            matTime = MatTime(context: context)
            if let uuid = UUID(uuidString: docSnapshot.documentID) {
                matTime?.id = uuid
                print("🟡 Creating new MatTime with ID: \(docSnapshot.documentID)")
            }
        } else {
            print("🟢 Updating existing MatTime with ID: \(docSnapshot.documentID)")
        }
        
        if let mt = matTime {
            mt.type = docSnapshot.get("type") as? String
            mt.time = docSnapshot.get("time") as? String
            mt.gi = docSnapshot.get("gi") as? Bool ?? false
            mt.noGi = docSnapshot.get("noGi") as? Bool ?? false
            mt.openMat = docSnapshot.get("openMat") as? Bool ?? false
            mt.restrictions = docSnapshot.get("restrictions") as? Bool ?? false
            mt.restrictionDescription = docSnapshot.get("restrictionDescription") as? String
            mt.goodForBeginners = docSnapshot.get("goodForBeginners") as? Bool ?? false
            mt.kids = docSnapshot.get("kids") as? Bool ?? false
            mt.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
            
            if let appDayOfWeekRef = docSnapshot.get("appDayOfWeek") as? DocumentReference,
               let appDayOfWeek = fetchAppDayOfWeekByID(appDayOfWeekRef.documentID, in: context) {
                mt.appDayOfWeek = appDayOfWeek
            }
        }
    }
    
    private func syncAppDayOfWeek(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var ado = fetchAppDayOfWeekByID(docSnapshot.documentID, in: context)
        if ado == nil {
            ado = AppDayOfWeek(context: context)
            ado?.appDayOfWeekID = docSnapshot.documentID
            print("🟡 Creating new AppDayOfWeek with ID: \(docSnapshot.documentID)")
        } else {
            print("🟢 Updating existing AppDayOfWeek with ID: \(docSnapshot.documentID)")
        }
        
        if let ado = ado {
            ado.day = docSnapshot.get("day") as? String ?? ""
            ado.name = docSnapshot.get("name") as? String
            ado.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
            
            // Link to PirateIsland
            if let pIslandData = docSnapshot.get("pIsland") as? [String: Any],
               let pirateIslandID = pIslandData["islandID"] as? String {
                if let pirateIsland = fetchPirateIslandByID(pirateIslandID, in: context) {
                    ado.pIsland = pirateIsland
                } else {
                    let newIsland = PirateIsland(context: context)
                    newIsland.islandID = UUID(uuidString: pirateIslandID)
                    newIsland.islandName = pIslandData["islandName"] as? String
                    newIsland.islandLocation = pIslandData["islandLocation"] as? String
                    newIsland.country = pIslandData["country"] as? String
                    newIsland.latitude = pIslandData["latitude"] as? Double ?? 0.0
                    newIsland.longitude = pIslandData["longitude"] as? Double ?? 0.0
                    ado.pIsland = newIsland
                }
            }
            
            // Link MatTimes
            if let matTimesArray = docSnapshot.get("matTimes") as? [String] {
                for matTimeID in matTimesArray {
                    if let matTime = fetchMatTimeByID(matTimeID, in: context) {
                        ado.addToMatTimes(matTime)
                    }
                }
            }
        }
    }

    
    
    private func fetchPirateIslandByID(_ id: String, in context: NSManagedObjectContext) -> PirateIsland? {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()

        guard let uuid = UUID(uuidString: id) else {
            print("Invalid UUID string: \(id)")
            return nil
        }

        fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching PirateIsland by ID: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchMatTimeByID(_ id: String, in context: NSManagedObjectContext) -> MatTime? {
        let fetchRequest: NSFetchRequest<MatTime> = MatTime.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching MatTime by ID: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchAppDayOfWeekByID(_ id: String, in context: NSManagedObjectContext) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "appDayOfWeekID == %@", id)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("❌ Error fetching AppDayOfWeek with ID \(id): \(error.localizedDescription)")
            return nil
        }
    }

    // Add this helper function somewhere in your class
    private func fetchReviewByID(_ id: String, in context: NSManagedObjectContext) -> Review? {
        // Explicitly cast the fetch request to NSFetchRequest<Review>
        let fetchRequest = Review.fetchRequest() as! NSFetchRequest<Review>

        guard let uuid = UUID(uuidString: id) else {
            print("Invalid UUID string for Review: \(id)")
            return nil
        }
        fetchRequest.predicate = NSPredicate(format: "reviewID == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching Review by ID: \(error.localizedDescription)")
            return nil
        }
    }
 

    private func syncAppDayOfWeekRecords() async {
        let db = Firestore.firestore()
        let collectionRef = db.collection("AppDayOfWeek")
        do {
            let querySnapshot = try await collectionRef.getDocuments()
            let firestoreRecords = querySnapshot.documents.compactMap { $0.documentID }

            let localRecords = try? await PersistenceController.shared.fetchLocalRecords(forCollection: "AppDayOfWeek")
            let localRecordsSet = Set(localRecords ?? [])
            let recordsToDownload = firestoreRecords.filter { !localRecordsSet.contains($0) }

            await downloadFirestoreRecordsToLocal(collectionName: "AppDayOfWeek", records: recordsToDownload)
        } catch {
            print("Error syncing appDayOfWeek records: \(error.localizedDescription)")
        }
    }
}


    
    


extension FirestoreSyncManager {
    // Keep active listener handles so you can detach them when needed
    private static var listenerRegistrations: [ListenerRegistration] = []

    @MainActor
    func startFirestoreListeners() {
        print("🟢 Starting Firestore listeners for all collections")
        listenToCollection("pirateIslands", handler: Self.handlePirateIslandChange)
        listenToCollection("reviews", handler: Self.handleReviewChange)
        listenToCollection("AppDayOfWeek", handler: Self.handleAppDayOfWeekChange)
        listenToCollection("MatTime", handler: Self.handleMatTimeChange)
    }


    func stopFirestoreListeners() {
        print("🔴 Stopping all Firestore listeners")
        for registration in Self.listenerRegistrations {
            registration.remove()
        }
        Self.listenerRegistrations.removeAll()
    }

    // MARK: - Generic listener
    @MainActor
    private func listenToCollection(
        _ collectionName: String,
        handler: @escaping (DocumentChange, NSManagedObjectContext) -> Void
    ) {
        let db = Firestore.firestore()
        let context = PersistenceController.shared.container.newBackgroundContext()

        let listener = db.collection(collectionName).addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ Firestore listener error for \(collectionName): \(error.localizedDescription)")
                return
            }

            guard let snapshot = snapshot else { return }

            for change in snapshot.documentChanges {
                context.perform {
                    handler(change, context)
                    do {
                        try context.save()
                    } catch {
                        print("❌ Error saving context for \(collectionName) listener: \(error.localizedDescription)")
                    }
                }
            }
        }

        Self.listenerRegistrations.append(listener)
    }

}

extension FirestoreSyncManager {
    // MARK: - Handlers for document changes

    static func handlePirateIslandChange(_ change: DocumentChange, _ context: NSManagedObjectContext) {
        switch change.type {
        case .added, .modified:
            try? syncPirateIslandStatic(docSnapshot: change.document, context: context)
        case .removed:
            deleteEntity(ofType: PirateIsland.self, idString: change.document.documentID, keyPath: \.islandID, context: context)
        }
    }

    static func handleReviewChange(_ change: DocumentChange, _ context: NSManagedObjectContext) {
        switch change.type {
        case .added, .modified:
            try? syncReviewStatic(docSnapshot: change.document, context: context)
        case .removed:
            deleteEntity(ofType: Review.self, idString: change.document.documentID, keyPath: \.reviewID, context: context)
        }
    }

    static func handleAppDayOfWeekChange(_ change: DocumentChange, _ context: NSManagedObjectContext) {
        switch change.type {
        case .added, .modified:
            try? syncAppDayOfWeekStatic(docSnapshot: change.document, context: context)
        case .removed:
            deleteEntity(ofType: AppDayOfWeek.self, idString: change.document.documentID, keyPath: \.appDayOfWeekID, context: context)
        }
    }

    static func handleMatTimeChange(_ change: DocumentChange, _ context: NSManagedObjectContext) {
        switch change.type {
        case .added, .modified:
            try? syncMatTimeStatic(docSnapshot: change.document, context: context)
        case .removed:
            deleteEntity(ofType: MatTime.self, idString: change.document.documentID, keyPath: \.id, context: context)
        }
    }

    // MARK: - Generic delete helper
    private static func deleteEntity<T: NSManagedObject, V>(
        ofType type: T.Type,
        idString: String,
        keyPath: KeyPath<T, V>,
        context: NSManagedObjectContext
    ) {
        guard let uuid = UUID(uuidString: idString) else { return }
        
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: type))
        fetchRequest.predicate = NSPredicate(format: "%K == %@", NSExpression(forKeyPath: keyPath).keyPath, uuid as CVarArg)
        fetchRequest.fetchLimit = 1

        if let object = try? context.fetch(fetchRequest).first {
            context.delete(object)
            print("🗑️ Deleted \(type) with ID \(idString) due to Firestore removal.")
        }
    }

}
