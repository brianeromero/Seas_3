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

extension FirestoreSyncManager {
    enum LogLevel: String {
        case info = "ℹ️"
        case success = "✅"
        case warning = "⚠️"
        case error = "❌"
        case creating = "🟡"
        case updating = "🟢"
        case sync = "🔄"
        case download = "📥"
        case upload = "🚀"
        case finished = "🏁"
    }
    
    static func log(
        _ message: String,
        level: LogLevel = .info,
        collection: String? = nil,
        syncID: String? = nil
    ) {
        var prefix = "[FirestoreSyncManager]"
        if let collection = collection {
            prefix += "[\(collection)]"
        }
        if let syncID = syncID {
            prefix += "[\(syncID)]"
        }
        print("\(level.rawValue) \(prefix) \(message)")
    }
}



// MARK: - Sync Coordinator
actor FirestoreSyncCoordinator {
    static let shared = FirestoreSyncCoordinator()
    private var isSyncInProgress = false

    func startAppSync() async {
        // ✅ Only sync if a user is logged in
        guard Auth.auth().currentUser != nil else {
            FirestoreSyncManager.log("⚠️ No user signed in — skipping sync.", level: .info)
            return
        }

        guard !isSyncInProgress else {
            FirestoreSyncManager.log("🚫 Sync already in progress — skipping duplicate call.", level: .warning)
            return
        }

        isSyncInProgress = true
        defer { isSyncInProgress = false }

        await FirestoreSyncManager.shared.syncInitialFirestoreData()
        await MainActor.run {
            FirestoreSyncManager.shared.startFirestoreListeners()
        }
    }
}


class FirestoreSyncManager {
    static let shared = FirestoreSyncManager()

    @MainActor
    func syncInitialFirestoreData() async {
        guard Auth.auth().currentUser != nil else {
            Self.log("No signed-in user. Skipping Firestore sync.", level: .warning)
            return
        }

        do {
            try await createFirestoreCollection() // setup/check step

            let db = Firestore.firestore()
            let collections = [
                "pirateIslands",
                "AppDayOfWeek",
                "MatTime",
                "reviews"
            ]

            for collectionName in collections {
                do {
                    try await downloadCollection(db: db, name: collectionName)
                } catch {
                    Self.log("Failed to download \(collectionName): \(error.localizedDescription)", level: .error, collection: collectionName)
                    // Continue with next collection
                }
            }

            Self.log("Initial Firestore sync complete", level: .finished)

        } catch {
            Self.log("Firestore setup/check error: \(error.localizedDescription)", level: .error)
        }
    }


    private func downloadCollection(db: Firestore, name: String) async throws {
        let snapshot = try await db.collection(name).getDocuments()
        let ids = snapshot.documents.map { $0.documentID }
        await downloadFirestoreRecordsToLocal(collectionName: name, records: ids)
        FirestoreSyncManager.log(
            "Downloaded \(ids.count) records from Firestore collection \(name)",
            level: .download,
            collection: name
        )
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
                        FirestoreSyncManager.log("No documents found in collection \(collectionName).", level: .warning, collection: collectionName)
                    } else {
                        FirestoreSyncManager.log("Collection \(collectionName) has \(querySnapshot.documents.count) documents.", level: .info, collection: collectionName)
                        FirestoreSyncManager.log("Document IDs: \(querySnapshot.documents.map { $0.documentID })", level: .info, collection: collectionName)
                    }
                }

                await self.checkLocalRecordsAndCreateFirestoreRecordsIfNecessary(collectionName: collectionName, querySnapshot: querySnapshot)
            } catch {
                FirestoreSyncManager.log("Error checking Firestore records for \(collectionName): \(error)", level: .error, collection: collectionName)
                throw error
            }
        }
    }

    
    private func checkLocalRecordsAndCreateFirestoreRecordsIfNecessary(
        collectionName: String,
        querySnapshot: QuerySnapshot?
    ) async {
        let syncID = String(UUID().uuidString.prefix(8))
        
        FirestoreSyncManager.log("Starting sync for \(collectionName)", level: .upload, collection: collectionName, syncID: syncID)
        FirestoreSyncManager.log("Initiating record check for collection: \(collectionName)", level: .upload, collection: collectionName, syncID: syncID)

        // ✅ Step 1: Check for network connection
        FirestoreSyncManager.log("""
        Checking network status before sync:
        - isConnected: \(NetworkMonitor.shared.isConnected)
        - currentPath: \(String(describing: NetworkMonitor.shared.currentPath))
        - currentStatus: \(String(describing: NetworkMonitor.shared.currentPath?.status))
        - hasShownNoInternetToast: \(Mirror(reflecting: NetworkMonitor.shared)
            .children.first { $0.label == "hasShownNoInternetToast" }?.value ?? "N/A")
        """, level: .info, collection: collectionName, syncID: syncID)

        guard NetworkMonitor.shared.isConnected else {
            FirestoreSyncManager.log("Network offline. Skipping \(collectionName) sync.", level: .warning, collection: collectionName, syncID: syncID)

            DispatchQueue.main.async {
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: "skipped",
                    type: .info,
                    isPersistent: true
                )
            }
            return
        }

        // ✅ Step 2: Ensure querySnapshot is valid
        guard let querySnapshot = querySnapshot else {
            FirestoreSyncManager.log("Query snapshot is nil for \(collectionName). Cannot proceed.", level: .error, collection: collectionName, syncID: syncID)
            return
        }

        FirestoreSyncManager.log("Query snapshot received for \(collectionName)", level: .success, collection: collectionName, syncID: syncID)

        let firestoreRecords = querySnapshot.documents.compactMap { $0.documentID }
        FirestoreSyncManager.log("Firestore records (\(firestoreRecords.count)): \(firestoreRecords.prefix(5))\(firestoreRecords.count > 5 ? "... (\(firestoreRecords.count - 5) more)" : "")", level: .download, collection: collectionName, syncID: syncID)

        do {
            if let localRecords = try await PersistenceController.shared.fetchLocalRecords(forCollection: collectionName) {
                FirestoreSyncManager.log("Local records (\(localRecords.count)): \(localRecords.prefix(5))\(localRecords.count > 5 ? "... (\(localRecords.count - 5) more)" : "")", level: .info, collection: collectionName, syncID: syncID)

                _ = Firestore.firestore().collection(collectionName)
                _ = await Task.detached(priority: .background) { [localRecords] in
                    var missing: [String] = []
                    let db = Firestore.firestore().collection(collectionName)

                    for chunk in localRecords.chunked(into: 10) {
                        let idsWithVariants = chunk.flatMap { id in [id, id.replacingOccurrences(of: "-", with: "")] }

                        do {
                            let snapshot = try await db.whereField("id", in: idsWithVariants).getDocuments()
                            let foundIDs = snapshot.documents.compactMap { $0.documentID }

                            for record in chunk where !foundIDs.contains(where: { $0 == record || $0.replacingOccurrences(of: "-", with: "") == $0 }) {
                                missing.append(record)
                            }
                        } catch {
                            FirestoreSyncManager.log(
                                "Error querying Firestore chunk (\(chunk.count)): \(error.localizedDescription)",
                                level: .warning,
                                collection: collectionName,
                                syncID: syncID
                            )
                        }
                    }

                    return missing
                }.value


                let localRecordsWithoutHyphens = Set(localRecords.map { $0.replacingOccurrences(of: "-", with: "") })
                _ = firestoreRecords.filter {
                    !localRecordsWithoutHyphens.contains($0.replacingOccurrences(of: "-", with: ""))
                }

                await syncRecords(localRecords: localRecords, firestoreRecords: firestoreRecords, collectionName: collectionName)
                FirestoreSyncManager.log("syncRecords completed for \(collectionName)", level: .sync, collection: collectionName, syncID: syncID)
 

            } else {
                FirestoreSyncManager.log("No local records found. Pulling from Firestore...", level: .warning, collection: collectionName, syncID: syncID)

                await syncRecords(localRecords: [], firestoreRecords: firestoreRecords, collectionName: collectionName)
                FirestoreSyncManager.log("syncRecords completed for \(collectionName) (no local records)", level: .sync, collection: collectionName, syncID: syncID)

                DispatchQueue.main.async {
                    ToastThrottler.shared.postToast(
                        for: collectionName,
                        action: "initialized from cloud",
                        type: .info,
                        isPersistent: false
                    )
                }
            }

        } catch {
            FirestoreSyncManager.log("Critical error fetching local records: \(error.localizedDescription)", level: .error, collection: collectionName, syncID: syncID)

            DispatchQueue.main.async {
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: "failed to fetch",
                    type: .error,
                    isPersistent: true
                )
            }
        }

        FirestoreSyncManager.log("Finished checking local records for \(collectionName)", level: .finished, collection: collectionName, syncID: syncID)
    }


    private func uploadLocalRecordsToFirestore(collectionName: String, records: [String]) async {
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)

        Self.log("Starting upload of \(records.count) local \(collectionName) records to Firestore", level: .upload, collection: collectionName)

        guard !records.isEmpty else {
            Self.log("No local \(collectionName) records to upload.", level: .info, collection: collectionName)
            return
        }

        let (uploadedCount, errorCount) = await Task.detached(priority: .background) { () -> (Int, Int) in
            var uploaded = 0
            var errors = 0

            for record in records {
                guard let recordUUID = UUID(uuidString: record) else {
                    errors += 1
                    await MainActor.run {
                        ToastThrottler.shared.postToast(
                            for: collectionName,
                            action: "invalid UUID \(record)",
                            type: .error,
                            isPersistent: true
                        )
                    }
                    continue
                }

                // Fetch local record safely on MainActor
                let localRecord: AnyObject? = await MainActor.run {
                    try? PersistenceController.shared.fetchLocalRecord(
                        forCollection: collectionName,
                        recordId: recordUUID
                    )
                }

                guard let localRecord else {
                    errors += 1
                    await MainActor.run {
                        ToastThrottler.shared.postToast(
                            for: collectionName,
                            action: "failed to fetch record \(record)",
                            type: .error,
                            isPersistent: true
                        )
                    }
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

                    let id = appDayOfWeek.appDayOfWeekID ?? ""

                    recordData = [
                        "id": id,                      // ← Firestore primary ID
                        "appDayOfWeekID": id,          // ← Must match Core Data primary ID
                        "day": appDayOfWeek.day,
                        "name": appDayOfWeek.name ?? "",
                        "createdTimestamp": appDayOfWeek.createdTimestamp ?? Date()
                    ]

                default:
                    continue
                }

                let docRef = collectionRef.document(record)

                do {
                    try await docRef.setData(recordData)
                    uploaded += 1
                    Self.log("Uploaded local record \(record) to Firestore (\(collectionName))", level: .success, collection: collectionName)
                } catch {
                    errors += 1
                    await MainActor.run {
                        ToastThrottler.shared.postToast(
                            for: collectionName,
                            action: "failed to upload record \(record)",
                            type: .error,
                            isPersistent: true
                        )
                    }
                    Self.log("Error uploading local record \(record) to Firestore: \(error.localizedDescription)", level: .error, collection: collectionName)
                }
            }

            return (uploaded, errors)
        }.value

        let finalLevel: LogLevel = errorCount > 0 ? .warning : .finished
        Self.log("Finished uploading local \(collectionName) records — succeeded: \(uploadedCount), failed: \(errorCount)", level: finalLevel, collection: collectionName)
    }

    
    // MARK: - Main download & sync coordinator
    private func syncRecords(localRecords: [String], firestoreRecords: [String], collectionName: String) async {
        // Normalize for comparison (Firestore removes hyphens)
        let normalizedFirestoreRecords = firestoreRecords.map { $0.replacingOccurrences(of: "-", with: "") }
        let normalizedLocalRecords = localRecords.map { $0.replacingOccurrences(of: "-", with: "") }
        
        // Identify records that exist locally but not remotely
        let localRecordsNotInFirestore = localRecords.filter { record in
            let normalized = record.replacingOccurrences(of: "-", with: "")
            return !normalizedFirestoreRecords.contains(normalized)
        }
        
        // Identify records that exist remotely but not locally
        let firestoreRecordsNotInLocal = firestoreRecords.filter { record in
            let normalized = record.replacingOccurrences(of: "-", with: "")
            return !normalizedLocalRecords.contains(normalized)
        }
        
        // Log summary header
        Self.log("""
        🔄 Starting sync for **\(collectionName)**:
           • 🆙 \(localRecordsNotInFirestore.count) local → Firestore
           • 📥 \(firestoreRecordsNotInLocal.count) Firestore → Core Data
        """)
        
        // Upload missing local records to Firestore
        if !localRecordsNotInFirestore.isEmpty {
            Self.log("⬆️ Uploading \(localRecordsNotInFirestore.count) missing local \(collectionName) records to Firestore…")
            await uploadLocalRecordsToFirestore(collectionName: collectionName, records: localRecordsNotInFirestore)
        } else {
            Self.log("✅ All \(collectionName) records already exist in Firestore. No upload needed.")
        }
        
        // Download missing Firestore records to Core Data
        if !firestoreRecordsNotInLocal.isEmpty {
            Self.log("⬇️ Downloading \(firestoreRecordsNotInLocal.count) missing Firestore \(collectionName) records into Core Data…")
            await downloadFirestoreRecordsToLocal(collectionName: collectionName, records: firestoreRecordsNotInLocal)
        } else {
            Self.log("✅ All \(collectionName) records already exist locally. No download needed.")
        }
        
        
        // Completion summary
        Self.log("""
        🏁 Finished sync for \(collectionName):
           • Uploaded: \(localRecordsNotInFirestore.count)
           • Downloaded: \(firestoreRecordsNotInLocal.count)
           • Total: \(localRecords.count + firestoreRecords.count)
        """)
        
        // --- Integrity check ---
        // **1. Re-fetch the current local count for an accurate check.**
        let currentLocalRecords = try? await PersistenceController.shared.fetchLocalRecords(forCollection: collectionName)
        let finalLocalCount = currentLocalRecords?.count ?? 0
        let initialFirestoreCount = firestoreRecords.count // This count is still accurate
        
        let countDifference = abs(finalLocalCount - initialFirestoreCount)
        
        Self.log("Integrity check: local=\(finalLocalCount), firestore=\(initialFirestoreCount)", level: .sync, collection: collectionName)
        
        DispatchQueue.main.async { // Post the final outcome on the main thread
            if countDifference > 0 {
                // CONDITION 3a: Sync failed to reconcile counts.
                Self.log("Count mismatch after sync — consider verifying orphaned records", level: .warning, collection: collectionName)
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: "Needs sync", // The true "needs sync" state, triggered by count mismatch
                    type: .info,
                    isPersistent: false
                )
            } else {
                // CONDITION 2b: Counts match (Syncd or Already Syncd)
                Self.log("Counts match — integrity check passed", level: .success, collection: collectionName)
                
                let action: String
                let type: ToastView.ToastType
                
                // If there was nothing to upload AND nothing to download, it was already synced.
                if localRecordsNotInFirestore.isEmpty && firestoreRecordsNotInLocal.isEmpty {
                    action = "Already Synced - All records confirmed"
                    type = .success
                } else {
                    action = "Synced successfully" // Changes were made, and the counts now match.
                    type = .success
                }
                
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: action,
                    type: type,
                    isPersistent: false
                )
            }
        }
    }

    @MainActor
    private func downloadFirestoreRecordsToLocal(collectionName: String, records: [String]) async {
        guard !records.isEmpty else {
            Self.log("⚠️ No Firestore records found to download for \(collectionName).")
            return
        }
        
        Self.log("📥 Starting Firestore → Core Data sync for **\(collectionName)** (\(records.count) total records)")
        
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        var downloadedCount = 0
        var errorCount = 0
        let batchSaveInterval = 10
        let syncID = String(UUID().uuidString.prefix(8))
        
        for record in records {
            // --- Logging must be on MainActor
            await MainActor.run {
                Self.log("🗂️ Found Firestore document ID: \(record)",
                         level: .info,
                         collection: collectionName,
                         syncID: syncID)
                Self.log("Attempting to fetch Firestore doc: \(record)",
                         level: .download,
                         collection: collectionName,
                         syncID: syncID)
            }

            let docRef = collectionRef.document(record)
            
            do {
                let docSnapshot = try await docRef.getDocument()
                
                guard docSnapshot.exists else {
                    await MainActor.run {
                        Self.log("⚠️ Firestore document not found or permission denied for: \(record)",
                                 level: .warning,
                                 collection: collectionName,
                                 syncID: syncID)
                    }
                    errorCount += 1
                    continue
                }
                
                await MainActor.run {
                    Self.log("✅ Successfully fetched Firestore doc: \(record)",
                             level: .success,
                             collection: collectionName,
                             syncID: syncID)
                }
                
                // --- Update Core Data via async static function
                switch collectionName {
                case "pirateIslands":
                    Self.syncPirateIslandStatic(docSnapshot: docSnapshot, context: context)
                case "reviews":
                    Self.syncReviewStatic(docSnapshot: docSnapshot, context: context)
                case "MatTime":
                    Self.syncMatTimeStatic(docSnapshot: docSnapshot, context: context)
                case "AppDayOfWeek":
                    Self.syncAppDayOfWeekStatic(docSnapshot: docSnapshot, context: context)
                default:
                    await MainActor.run {
                        Self.log("⚠️ Unknown collection: \(collectionName)",
                                 level: .warning,
                                 collection: collectionName,
                                 syncID: syncID)
                    }
                    errorCount += 1
                    continue
                }
                
                downloadedCount += 1
                
                // --- Intermediate save in background context
                await context.perform {
                    if downloadedCount % batchSaveInterval == 0, context.hasChanges {
                        do {
                            try context.save()
                            Task { @MainActor in
                                Self.log("💾 Intermediate save after \(downloadedCount) synced records",
                                         level: .info,
                                         collection: collectionName,
                                         syncID: syncID)
                            }
                        } catch {
                            context.rollback()
                            Task { @MainActor in
                                Self.log("❌ Core Data error during intermediate save: \(error.localizedDescription)",
                                         level: .error,
                                         collection: collectionName,
                                         syncID: syncID)
                            }
                            errorCount += 1
                        }
                    }
                }
                
                await MainActor.run {
                    Self.log("✅ Synced \(collectionName) record: \(record)",
                             level: .success,
                             collection: collectionName,
                             syncID: syncID)
                }
                
            } catch {
                await MainActor.run {
                    Self.log("❌ Error fetching Firestore doc: \(record) → \(error.localizedDescription)",
                             level: .error,
                             collection: collectionName,
                             syncID: syncID)
                }
                errorCount += 1
            }
        }
        
        // --- Final save after loop
        await context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                    Task { @MainActor in
                        Self.log("💾 Final Core Data save for \(collectionName).",
                                 level: .info,
                                 collection: collectionName,
                                 syncID: syncID)
                    }
                } catch {
                    context.rollback()
                    Task { @MainActor in
                        Self.log("❌ Error performing final save for \(collectionName): \(error.localizedDescription)",
                                 level: .error,
                                 collection: collectionName,
                                 syncID: syncID)
                    }
                    errorCount += 1
                }
            }
        }
        
        // --- Summary & Toast
        var summary: String
        var toastType: ToastView.ToastType
        
        if downloadedCount > 0 && errorCount == 0 {
            summary = "✅ Downloaded all \(downloadedCount) records"
            toastType = .success
        } else if downloadedCount > 0 {
            summary = "⚠️ \(downloadedCount) succeeded, \(errorCount) failed"
            toastType = .info
        } else {
            summary = "❌ All \(records.count) downloads failed"
            toastType = .error
        }
        
        _ = summary
        _ = toastType
        
        Self.log("🏁 Firestore sync complete for \(collectionName): \(downloadedCount) succeeded | \(errorCount) failed")
    }


    // MARK: - Static helpers for Firestore sync
    // ---------------------------
    // PirateIsland
    // ---------------------------
    private static func syncPirateIslandStatic(
        docSnapshot: DocumentSnapshot,
        context: NSManagedObjectContext
    ) {
        let data = docSnapshot.data() ?? [:]
        guard !data.isEmpty else { return }

        let islandName = data["islandName"] as? String ?? data["name"] as? String
        let islandLocation = data["islandLocation"] as? String ?? data["location"] as? String

        guard let name = islandName, let location = islandLocation else {
            Task { @MainActor in
                FirestoreSyncManager.log(
                    "⚠️ Missing required fields for PirateIsland \(docSnapshot.documentID). Skipping.",
                    level: .error,
                    collection: "pirateIslands"
                )
            }
            return
        }

        let country = data["country"] as? String
        let createdByUserId = data["createdByUserId"] as? String
        let lastModifiedByUserId = data["lastModifiedByUserId"] as? String
        let createdTimestamp = (data["createdTimestamp"] as? Timestamp)?.dateValue() ?? Date()
        let lastModifiedTimestamp = (data["lastModifiedTimestamp"] as? Timestamp)?.dateValue() ?? Date()
        let latitude = data["latitude"] as? Double ?? 0.0
        let longitude = data["longitude"] as? Double ?? 0.0
        let gymWebsiteString = data["gymWebsite"] as? String
        let gymWebsite = gymWebsiteString != nil ? URL(string: gymWebsiteString!) : nil

        context.perform {
            let fetchRequest = PirateIsland.fetchRequest()
            if let uuid = UUID(uuidString: docSnapshot.documentID) {
                fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
            } else {
                fetchRequest.predicate = NSPredicate(format: "islandIDString == %@", docSnapshot.documentID)
            }

            do {
                let results = try context.fetch(fetchRequest)
                let island = results.first ?? PirateIsland(context: context)

                island.islandID = UUID(uuidString: docSnapshot.documentID)
                island.islandName = name
                island.islandLocation = location
                island.country = country
                island.createdByUserId = createdByUserId
                island.createdTimestamp = createdTimestamp
                island.lastModifiedByUserId = lastModifiedByUserId
                island.lastModifiedTimestamp = lastModifiedTimestamp
                island.latitude = latitude
                island.longitude = longitude
                island.gymWebsite = gymWebsite

                if context.hasChanges {
                    try context.save()
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "✅ Synced pirateIslands record: \(docSnapshot.documentID)",
                            level: .success,
                            collection: "pirateIslands"
                        )
                    }
                } else {
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "ℹ️ No changes detected for PirateIsland \(docSnapshot.documentID), skipping save.",
                            level: .info,
                            collection: "pirateIslands"
                        )
                    }
                }
            } catch {
                Task { @MainActor in
                    FirestoreSyncManager.log(
                        "❌ Failed syncing pirateIsland \(docSnapshot.documentID): \(error)",
                        level: .error,
                        collection: "pirateIslands"
                    )
                }
            }
        }
    }

    // ---------------------------
    // Review
    // ---------------------------
    private static func syncReviewStatic(
        docSnapshot: DocumentSnapshot,
        context: NSManagedObjectContext
    ) {
        context.perform {
            let data = docSnapshot.data() ?? [:]
            guard !data.isEmpty else { return }

            let documentID = docSnapshot.documentID
            let reviewUUID: UUID = UUID(uuidString: documentID) ?? UUID.fromStringID(documentID)

            let fetchRequest = Review.fetchRequest() as! NSFetchRequest<Review>
            fetchRequest.predicate = NSPredicate(format: "reviewID == %@", reviewUUID as CVarArg)
            fetchRequest.fetchLimit = 1

            let review = (try? context.fetch(fetchRequest).first) ?? Review(context: context)
            review.reviewID = reviewUUID
            review.stars = (data["stars"] as? Int16) ?? Int16(data["stars"] as? Int ?? 0)
            review.review = data["review"] as? String ?? ""
            review.userName = data["userName"] as? String ?? data["name"] as? String ?? "Anonymous"
            review.createdTimestamp = (data["createdTimestamp"] as? Timestamp)?.dateValue() ?? Date()

            if let islandIDString = data["islandID"] as? String {
                let islandUUID = UUID(uuidString: islandIDString) ?? UUID.fromStringID(islandIDString)
                let islandFetch: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                islandFetch.predicate = NSPredicate(format: "islandID == %@", islandUUID as CVarArg)
                islandFetch.fetchLimit = 1

                if let island = try? context.fetch(islandFetch).first {
                    review.island = island
                } else {
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "⚠️ Island not found for review \(documentID) (islandID: \(islandIDString))",
                            level: .warning,
                            collection: "Review"
                        )
                    }
                }
            }

            if context.hasChanges {
                do {
                    try context.save()
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "✅ Synced Review \(documentID)",
                            level: .success,
                            collection: "Review"
                        )
                    }
                } catch {
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "❌ Save failed for Review \(documentID): \(error.localizedDescription)",
                            level: .error,
                            collection: "Review"
                        )
                    }
                }
            } else {
                Task { @MainActor in
                    FirestoreSyncManager.log(
                        "ℹ️ No changes for Review \(documentID)",
                        level: .info,
                        collection: "Review"
                    )
                }
            }
        }
    }


    // ---------------------------
    // MatTime
    // ---------------------------
    private static func syncMatTimeStatic(
        docSnapshot: DocumentSnapshot,
        context: NSManagedObjectContext
    ) {

        var logBlock: (() -> Void)? = nil

        context.perform {
            let docID = docSnapshot.documentID
            let uuid: UUID = UUID(uuidString: docID) ?? UUID.fromStringID(docID)

            let fetchRequest: NSFetchRequest<MatTime> = MatTime.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                let matTime = try context.fetch(fetchRequest).first ?? MatTime(context: context)
                matTime.id = uuid

                // Mapping
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

                // AppDayOfWeek linking
                if let appDayRef = docSnapshot.get("appDayOfWeek") as? DocumentReference {
                    let rawID = appDayRef.documentID
                    let normalizedID = UUID(uuidString: rawID)?.uuidString ?? rawID

                    let dayFetch: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
                    dayFetch.predicate = NSPredicate(
                        format: "appDayOfWeekID == %@ OR appDayOfWeekID == %@",
                        normalizedID,
                        rawID
                    )
                    dayFetch.fetchLimit = 1

                    if let appDay = try? context.fetch(dayFetch).first {
                        matTime.appDayOfWeek = appDay
                    }
                }

                // Save
                if context.hasChanges {
                    do {
                        try context.save()
                        logBlock = {
                            Self.log("✅ Synced MatTime \(docID)",
                                     level: .success,
                                     collection: "MatTime")
                        }
                    } catch {
                        logBlock = {
                            Self.log("❌ Failed saving MatTime \(docID): \(error.localizedDescription)",
                                     level: .error,
                                     collection: "MatTime")
                        }
                    }
                }
            } catch {
                logBlock = {
                    Self.log("❌ Failed syncing MatTime \(docSnapshot.documentID): \(error)",
                             level: .error,
                             collection: "MatTime")
                }
            }
        }

        // 🌟 MAIN-ACTOR logging, after core data work is done
        if let logBlock {
            Task { @MainActor in logBlock() }
        }
    }



    // ---------------------------
    // AppDayOfWeek
    // ---------------------------
    private static func syncAppDayOfWeekStatic(
        docSnapshot: DocumentSnapshot,
        context: NSManagedObjectContext
    ) {
        // Defensive check: warn if using main context
        #if DEBUG
        if context.concurrencyType != .privateQueueConcurrencyType {
            print("❌ ERROR: syncAppDayOfWeekStatic called with MAIN context! Must use background context!")
        }
        #endif

        context.perform {
            let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
            let docID = docSnapshot.documentID
            let uuidVersion = UUID.fromStringID(docID).uuidString

            fetchRequest.predicate = NSPredicate(
                format: "appDayOfWeekID == %@ OR appDayOfWeekID == %@",
                docID,
                uuidVersion
            )
            fetchRequest.fetchLimit = 1

            do {
                let ado: AppDayOfWeek
                if let existing = try context.fetch(fetchRequest).first {
                    ado = existing
                } else {
                    ado = AppDayOfWeek(context: context)
                    ado.appDayOfWeekID = docID
                }

                // --- Map Firestore fields
                guard let day = docSnapshot.get("day") as? String, !day.isEmpty else {
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "❌ Invalid AppDayOfWeek (missing day) — skipping",
                            level: .error,
                            collection: "AppDayOfWeek"
                        )
                    }
                    return
                }
                ado.day = day

                if let nameFromFS = docSnapshot.get("name") as? String {
                    ado.name = nameFromFS
                } else if let islandName = (docSnapshot.get("pIsland") as? [String: Any])?["islandName"] as? String {
                    ado.name = "\(islandName) - \(day)"
                } else {
                    ado.name = day
                }

                if let ts = docSnapshot.get("createdTimestamp") as? Timestamp {
                    ado.createdTimestamp = ts.dateValue()
                } else if ado.createdTimestamp == nil {
                    ado.createdTimestamp = Date()
                }

                // --- Link PirateIsland
                if let pIslandData = docSnapshot.get("pIsland") as? [String: Any],
                   let pirateIslandIDString = pIslandData["islandID"] as? String {

                    let pirateUUID = UUID.fromStringID(pirateIslandIDString)

                    let islandFetch: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                    islandFetch.predicate = NSPredicate(format: "islandID == %@", pirateUUID as CVarArg)
                    islandFetch.fetchLimit = 1

                    let island: PirateIsland
                    if let existingIsland = try context.fetch(islandFetch).first {
                        island = existingIsland
                    } else {
                        // Create new island
                        island = PirateIsland(context: context)
                        island.islandID = pirateUUID
                        island.islandName = pIslandData["islandName"] as? String ?? pIslandData["name"] as? String
                        island.islandLocation = pIslandData["islandLocation"] as? String ?? pIslandData["location"] as? String
                        island.country = pIslandData["country"] as? String
                        island.createdTimestamp = (pIslandData["createdTimestamp"] as? Timestamp)?.dateValue() ?? Date()
                        island.latitude = pIslandData["latitude"] as? Double ?? 0.0
                        island.longitude = pIslandData["longitude"] as? Double ?? 0.0
                        if let urlString = pIslandData["gymWebsite"] as? String {
                            island.gymWebsite = URL(string: urlString)
                        }
                    }

                    ado.pIsland = island
                }

                // --- Save background context only
                if context.hasChanges {
                    do {
                        try context.save()

                        // Log on main thread
                        Task { @MainActor in
                            FirestoreSyncManager.log(
                                "✅ Synced AppDayOfWeek \(docID)",
                                level: .success,
                                collection: "AppDayOfWeek"
                            )
                        }
                    } catch {
                        Task { @MainActor in
                            FirestoreSyncManager.log(
                                "❌ Failed background save AppDayOfWeek \(docID): \(error.localizedDescription)",
                                level: .error,
                                collection: "AppDayOfWeek"
                            )
                        }
                    }
                }

            } catch {
                Task { @MainActor in
                    FirestoreSyncManager.log(
                        "❌ Failed syncing AppDayOfWeek \(docID): \(error)",
                        level: .error,
                        collection: "AppDayOfWeek"
                    )
                }
            }
        }
    }
}

extension FirestoreSyncManager {
    // Keep active listener handles so you can detach them when needed
    private static var listenerRegistrations: [ListenerRegistration] = []

    @MainActor
    func startFirestoreListeners() {
        Self.log("Starting Firestore listeners for all collections", level: .updating)
        listenToCollection("pirateIslands", handler: Self.handlePirateIslandChange)
        listenToCollection("reviews", handler: Self.handleReviewChange)
        listenToCollection("AppDayOfWeek", handler: Self.handleAppDayOfWeekChange)
        listenToCollection("MatTime", handler: Self.handleMatTimeChange)
    }

    func stopFirestoreListeners() {
        Self.log("Stopping all Firestore listeners", level: .warning)
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
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()

        let listener = db.collection(collectionName).addSnapshotListener { snapshot, error in
            if let error = error {
                Task { @MainActor in
                    Self.log("Listener error: \(error.localizedDescription)",
                             level: .error,
                             collection: collectionName)
                }
                return
            }

            guard let snapshot = snapshot else { return }

            for change in snapshot.documentChanges {

                backgroundContext.perform {
                    // Run handler on background context (no @Published updates here!)
                    handler(change, backgroundContext)

                    do {
                        if backgroundContext.hasChanges {
                            try backgroundContext.save()
                        }

                        // Merge background changes to main context safely
                        Task { @MainActor in
                            let mainContext = PersistenceController.shared.container.viewContext
                            let saveNotification = Notification(
                                name: .NSManagedObjectContextDidSave,
                                object: backgroundContext,
                                userInfo: nil
                            )
                            mainContext.mergeChanges(fromContextDidSave: saveNotification)

                            Self.log("✅ Merged background listener changes for \(collectionName)",
                                     level: .success,
                                     collection: collectionName)
                        }

                    } catch {
                        Task { @MainActor in
                            Self.log("❌ Background context save error in listener: \(error.localizedDescription)",
                                     level: .error,
                                     collection: collectionName)
                        }
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
            syncPirateIslandStatic(docSnapshot: change.document, context: context)
        case .removed:
            deleteEntity(ofType: PirateIsland.self, idString: change.document.documentID, keyPath: \.islandID, context: context)
        }
    }

    static func handleReviewChange(_ change: DocumentChange, _ context: NSManagedObjectContext) {
        switch change.type {
        case .added, .modified:
            syncReviewStatic(docSnapshot: change.document, context: context)
        case .removed:
            deleteEntity(ofType: Review.self, idString: change.document.documentID, keyPath: \.reviewID, context: context)
        }
    }

    static func handleAppDayOfWeekChange(_ change: DocumentChange, _ context: NSManagedObjectContext) {
        switch change.type {
        case .added, .modified:
            syncAppDayOfWeekStatic(docSnapshot: change.document, context: context)
        case .removed:
            deleteEntity(ofType: AppDayOfWeek.self, idString: change.document.documentID, keyPath: \.appDayOfWeekID, context: context)
        }
    }

    static func handleMatTimeChange(_ change: DocumentChange, _ context: NSManagedObjectContext) {
        switch change.type {
        case .added, .modified:
            syncMatTimeStatic(docSnapshot: change.document, context: context)
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
            Self.log("🗑️ Deleted \(type) with ID \(idString) due to Firestore removal.",
                     level: .warning,
                     collection: String(describing: type))
        }
    }


}


// MARK: - Utility Extension
extension Array {
    /// Breaks an array into chunks of the given size (Firestore 'in' queries support up to 10)
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}




extension UUID {

    /// Converts any string-based Firestore ID into a deterministic UUID.
    /// If the string is already 36-char UUID, it returns it directly.
    /// If not, generates a stable UUID using a hash.
    static func fromStringID(_ string: String) -> UUID {
        if let uuid = UUID(uuidString: string) {
            return uuid
        }

        // Convert arbitrary string → stable UUID
        var hasher = Hasher()
        hasher.combine(string)
        let hashValue = hasher.finalize()

        // Use hash value to construct a stable UUID from the string
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: hashValue.bigEndian) { buffer in
            let count = min(buffer.count, 16)
            for i in 0..<count {
                uuidBytes[i] = buffer[i]
            }
        }

        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }
}
