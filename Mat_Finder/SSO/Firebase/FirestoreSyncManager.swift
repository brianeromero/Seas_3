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
        let syncID = UUID().uuidString.prefix(8)
        print("🚀 [SyncManager:\(syncID)] Starting sync for \(collectionName)")
        print("🚀 [SyncManager:\(syncID)] Initiating record check for collection: \(collectionName)")

        // ✅ Step 1: Check for network connection
        print("""
        🌐 [SyncManager:\(syncID)] Checking network status before sync:
        - isConnected: \(NetworkMonitor.shared.isConnected)
        - currentPath: \(String(describing: NetworkMonitor.shared.currentPath))
        - currentStatus: \(String(describing: NetworkMonitor.shared.currentPath?.status))
        - hasShownNoInternetToast: \(Mirror(reflecting: NetworkMonitor.shared).children.first { $0.label == "hasShownNoInternetToast" }?.value ?? "N/A")
        """)

        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ [SyncManager:\(syncID)] Network offline. Skipping \(collectionName) sync.")

            // Use ToastThrottler for persistent offline toast
            DispatchQueue.main.async {
                ToastThrottler.shared.postToast(
                    for: collectionName,          // logical record key
                    action: "skipped",            // action that occurred
                    type: .info,                  // ToastView.ToastType
                    isPersistent: true
                )
            }
            return
        }


        // ✅ Step 2: Ensure querySnapshot is valid
        guard let querySnapshot = querySnapshot else {
            print("❌ [SyncManager] Query snapshot is nil for collection \(collectionName). Cannot proceed.")
            return
        }

        print("✅ [SyncManager] Query snapshot received for collection: \(collectionName)")

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

                let localRecordsWithoutHyphens = Set(localRecords.map { $0.replacingOccurrences(of: "-", with: "") })
                let firestoreRecordsNotInLocal = firestoreRecords.filter { !localRecordsWithoutHyphens.contains($0.replacingOccurrences(of: "-", with: "")) }

                await syncRecords(localRecords: localRecords, firestoreRecords: firestoreRecords, collectionName: collectionName)
                print("🔄 [SyncManager] `syncRecords` completed for collection: \(collectionName)")

                // Post toast based on sync state
                DispatchQueue.main.async {
                    if !localRecordsNotInFirestore.isEmpty || !firestoreRecordsNotInLocal.isEmpty {
                        // ⚠️ There are unsynced records
                        ToastThrottler.shared.postToast(
                            for: collectionName,       // logical record key
                            action: "needs sync",      // descriptive action
                            type: .error,              // ToastView.ToastType
                            isPersistent: false
                        )
                    } else {
                        // ✅ Everything is synced
                        ToastThrottler.shared.postToast(
                            for: collectionName,
                            action: "synced successfully",
                            type: .success,
                            isPersistent: false
                        )
                    }
                }
            } else {
                print("⚠️ [SyncManager] No local records found for \(collectionName). Proceeding to sync from Firestore.")

                await syncRecords(localRecords: [], firestoreRecords: firestoreRecords, collectionName: collectionName)
                print("🔄 [SyncManager] `syncRecords` completed for collection: \(collectionName) (no local records)")

                DispatchQueue.main.async {
                    ToastThrottler.shared.postToast(
                        for: collectionName,        // logical record key
                        action: "initialized from cloud", // descriptive action
                        type: .info,                // ToastView.ToastType enum
                        isPersistent: false
                    )
                }

            }
        } catch {
            print("❌ [SyncManager] Critical error during local record fetch for \(collectionName): \(error.localizedDescription)")

            DispatchQueue.main.async {
                ToastThrottler.shared.postToast(
                    for: collectionName,           // logical record key
                    action: "failed to fetch",     // descriptive action
                    type: .error,                  // ToastView.ToastType
                    isPersistent: true             // keep visible for errors
                )
            }
        }


        print("🏁 [SyncManager] Finished checking local records for collection: \(collectionName)")
    }

    
    @MainActor
    private func uploadLocalRecordsToFirestore(collectionName: String, records: [String]) async {
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)
        
        print("🚀 [SyncManager] Starting upload of \(records.count) local \(collectionName) records to Firestore")
        
        for record in records {
            // Fetch the full local record from Core Data
            guard let localRecord = try? PersistenceController.shared.fetchLocalRecord(
                forCollection: collectionName,
                recordId: UUID(uuidString: record) ?? UUID()
            ) else {
                print("❌ Error fetching local record \(record) from Core Data")
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: "failed to fetch record \(record)",
                    type: .error,
                    isPersistent: true
                )
                continue
            }
            
            // Map Core Data object to dictionary
            var recordData: [String: Any] = [:]
            switch collectionName {
            case "pirateIslands":
                guard let pirateIsland = localRecord as? PirateIsland else { continue }
                recordData = [
                    "id": pirateIsland.islandID?.uuidString ?? "",
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
                    "id": matTime.id?.uuidString ?? "",
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
                    "appDayOfWeekID": matTime.appDayOfWeek?.appDayOfWeekID ?? ""
                ]
                
            case "AppDayOfWeek":
                guard let appDayOfWeek = localRecord as? AppDayOfWeek else { continue }
                recordData = [
                    "id": appDayOfWeek.appDayOfWeekID ?? "",
                    "day": appDayOfWeek.day,
                    "name": appDayOfWeek.name ?? "",
                    "createdTimestamp": appDayOfWeek.createdTimestamp ?? Date()
                ]
                
            default:
                print("❌ Unknown collection name: \(collectionName)")
                continue
            }
            
            let docRef = collectionRef.document(record)
            
            // Upload to Firestore
            do {
                try await docRef.setData(recordData)
                print("✅ Uploaded local record \(record) to Firestore (\(collectionName))")
            } catch {
                print("❌ Error uploading local record \(record) to Firestore: \(error.localizedDescription)")
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: "failed to upload record \(record)",
                    type: .error,
                    isPersistent: true
                )
            }
        }
        
        print("🏁 Finished uploading local \(collectionName) records to Firestore")
    }

    
    // MARK: - Main download function
    private func syncRecords(localRecords: [String], firestoreRecords: [String], collectionName: String) async {
        // Identify records in Core Data but not in Firestore
        let localRecordsNotInFirestore = localRecords.filter { record in
            let normalized = record.replacingOccurrences(of: "-", with: "")
            return !firestoreRecords.contains(record) && !firestoreRecords.map { $0.replacingOccurrences(of: "-", with: "") }.contains(normalized)
        }
        
        // Identify records in Firestore but not in Core Data
        let localRecordsNormalized = Set(localRecords.map { $0.replacingOccurrences(of: "-", with: "") })
        let firestoreRecordsNotInLocal = firestoreRecords.filter { !localRecordsNormalized.contains($0.replacingOccurrences(of: "-", with: "")) }
        
        print("🔄 Syncing \(collectionName): \(localRecordsNotInFirestore.count) local -> Firestore, \(firestoreRecordsNotInLocal.count) Firestore -> local")
        
        // Upload local records not in Firestore
        await uploadLocalRecordsToFirestore(collectionName: collectionName, records: localRecordsNotInFirestore)
        
        // Download Firestore records not in local Core Data
        await downloadFirestoreRecordsToLocal(collectionName: collectionName, records: firestoreRecordsNotInLocal)
    }

    
    @MainActor
    private func downloadFirestoreRecordsToLocal(collectionName: String, records: [String]) async {
        guard !records.isEmpty else { return }
        
        print("📥 Downloading \(records.count) Firestore records for \(collectionName) into Core Data")
        
        // Initial info toast
        ToastThrottler.shared.postToast(
            for: collectionName,
            action: "downloading \(records.count) from cloud",
            type: .info,
            isPersistent: false
        )
        
        let context = PersistenceController.shared.container.newBackgroundContext()
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)
        
        var downloadedCount = 0
        var errorCount = 0
        
        for record in records {
            let docRef = collectionRef.document(record)
            
            do {
                let docSnapshot = try await docRef.getDocument()
                guard docSnapshot.exists else {
                    print("❌ Firestore document \(record) does not exist. Skipping.")
                    errorCount += 1
                    continue
                }
                
                await context.perform {
                    do {
                        switch collectionName {
                        case "pirateIslands":
                            try Self.syncPirateIslandStatic(docSnapshot: docSnapshot, context: context)
                        case "reviews":
                            try Self.syncReviewStatic(docSnapshot: docSnapshot, context: context)
                        case "MatTime":
                            try Self.syncMatTimeStatic(docSnapshot: docSnapshot, context: context)
                        case "AppDayOfWeek":
                            try Self.syncAppDayOfWeekStatic(docSnapshot: docSnapshot, context: context)
                        default:
                            print("❌ Unknown collection: \(collectionName)")
                            errorCount += 1
                            return
                        }
                        
                        try context.save()
                        downloadedCount += 1
                        print("✅ Synced \(collectionName) record \(record) to Core Data")
                    } catch {
                        context.rollback()
                        print("❌ Error syncing \(collectionName) record \(record): \(error)")
                        errorCount += 1
                    }
                }
                
            } catch {
                print("❌ Error fetching Firestore document \(record) for \(collectionName): \(error.localizedDescription)")
                errorCount += 1
            }
        }
        
        // Final toast
        let actionMessage: String
        let toastType: ToastView.ToastType
        
        if downloadedCount > 0 && errorCount == 0 {
            actionMessage = "Successfully downloaded \(downloadedCount) records"
            toastType = .success
        } else if downloadedCount > 0 {
            actionMessage = "Downloaded \(downloadedCount) records, \(errorCount) failed"
            toastType = .info
        } else {
            actionMessage = "Failed to download any records"
            toastType = .error
        }
        
        ToastThrottler.shared.postToast(
            for: collectionName,
            action: actionMessage,
            type: toastType,
            isPersistent: false
        )
        
        print("🏁 Finished downloading \(collectionName) records: \(downloadedCount) succeeded, \(errorCount) failed")
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
