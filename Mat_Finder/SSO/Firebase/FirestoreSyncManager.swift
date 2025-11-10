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

    func syncInitialFirestoreData() async {
        guard Auth.auth().currentUser != nil else {
            FirestoreSyncManager.log(
                "No user is signed in. Firestore access is restricted.",
                level: .error
            )
            return
        }

        do {
            // Step 0: Ensure collections exist first
            try await createFirestoreCollection()

            let db = Firestore.firestore()

            // --- Step 1: Fetch Pirate Islands
            let pirateSnapshot = try await db.collection("pirateIslands").getDocuments()
            let pirateIslandIDs = pirateSnapshot.documents.map { $0.documentID }
            print("📋 Firestore returned PirateIsland IDs:", pirateIslandIDs)
            await downloadFirestoreRecordsToLocal(
                collectionName: "pirateIslands",
                records: pirateIslandIDs
            )
            FirestoreSyncManager.log(
                "Downloaded \(pirateIslandIDs.count) pirate islands from Firestore",
                level: .success,
                collection: "pirateIslands"
            )

            // --- Step 2: Fetch AppDayOfWeek (must come before MatTime)
            let appDaySnapshot = try await db.collection("AppDayOfWeek").getDocuments()
            let appDayOfWeekIDs = appDaySnapshot.documents.map { $0.documentID }
            await downloadFirestoreRecordsToLocal(
                collectionName: "AppDayOfWeek",
                records: appDayOfWeekIDs
            )
            FirestoreSyncManager.log(
                "Downloaded \(appDayOfWeekIDs.count) AppDayOfWeek records from Firestore",
                level: .success,
                collection: "AppDayOfWeek"
            )

            // --- Step 3: Fetch MatTime (depends on AppDayOfWeek)
            let matTimeSnapshot = try await db.collection("MatTime").getDocuments()
            let matTimeIDs = matTimeSnapshot.documents.map { $0.documentID }
            await downloadFirestoreRecordsToLocal(
                collectionName: "MatTime",
                records: matTimeIDs
            )
            FirestoreSyncManager.log(
                "Downloaded \(matTimeIDs.count) MatTime records from Firestore",
                level: .success,
                collection: "MatTime"
            )

            // --- Step 4: Fetch Reviews (depends on PirateIsland)
            let reviewSnapshot = try await db.collection("reviews").getDocuments()
            let reviewIDs = reviewSnapshot.documents.map { $0.documentID }
            await downloadFirestoreRecordsToLocal(
                collectionName: "reviews",
                records: reviewIDs
            )
            FirestoreSyncManager.log(
                "Downloaded \(reviewIDs.count) reviews from Firestore",
                level: .success,
                collection: "reviews"
            )

            FirestoreSyncManager.log(
                "✅ Initial Firestore sync complete",
                level: .success
            )

        } catch {
            FirestoreSyncManager.log(
                "Firestore sync error: \(error.localizedDescription)",
                level: .error
            )
        }
    }


    private func downloadCollection(db: Firestore, name: String) async throws {
        let snapshot = try await db.collection(name).getDocuments()
        let ids = snapshot.documents.map { $0.documentID }
        await downloadFirestoreRecordsToLocal(collectionName: name, records: ids)
        FirestoreSyncManager.log("Downloaded \(ids.count) records from Firestore collection \(name)", level: .download, collection: name)
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
                    recordData = [
                        "id": appDayOfWeek.appDayOfWeekID ?? "",
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
        
        let result = await Task.detached(priority: .background) { () -> (downloadedCount: Int, errorCount: Int) in
            let context = await PersistenceController.shared.container.newBackgroundContext()
            let db = Firestore.firestore()
            let collectionRef = db.collection(collectionName)
            
            var downloadedCount = 0
            var errorCount = 0
            let batchSaveInterval = 10
            let syncID = String(UUID().uuidString.prefix(8))
            
            for record in records {
                // 🧩 Diagnostic Addition
                Self.log("🗂️ Found Firestore document ID: \(record)", level: .info, collection: collectionName, syncID: syncID)
                
                let docRef = collectionRef.document(record)
                Self.log("Attempting to fetch Firestore doc: \(record)", level: .download, collection: collectionName, syncID: syncID)
                
                do {
                    let docSnapshot = try await docRef.getDocument()
                    
                    guard docSnapshot.exists else {
                        Self.log("⚠️ Firestore document not found or permission denied for: \(record)",
                                 level: .warning,
                                 collection: collectionName,
                                 syncID: syncID)
                        errorCount += 1
                        continue
                    }
                    
                    Self.log("✅ Successfully fetched Firestore doc: \(record)",
                             level: .success,
                             collection: collectionName,
                             syncID: syncID)
                    
                    await context.perform {
                        do {
                            switch collectionName {
                            case "pirateIslands":
                                try Self.syncPirateIslandStatic(docSnapshot: docSnapshot, context: context)
                            case "reviews":
                                try Self.syncReviewStatic(docSnapshot: docSnapshot, context: context)
                            case "MatTime": // ✅ Fixed name
                                try Self.syncMatTimeStatic(docSnapshot: docSnapshot, context: context)
                            case "AppDayOfWeek": // ✅ Fixed name
                                try Self.syncAppDayOfWeekStatic(docSnapshot: docSnapshot, context: context)
                            default:
                                Self.log("⚠️ Unknown collection: \(collectionName)",
                                         level: .warning,
                                         collection: collectionName,
                                         syncID: syncID)
                                errorCount += 1
                                return
                            }


                            
                            downloadedCount += 1
                            
                            if downloadedCount % batchSaveInterval == 0 {
                                try context.save()
                                Self.log("💾 Intermediate save after \(downloadedCount) synced records",
                                         level: .info,
                                         collection: collectionName,
                                         syncID: syncID)
                            }
                            
                            Self.log("✅ Synced \(collectionName) record: \(record)",
                                     level: .success,
                                     collection: collectionName,
                                     syncID: syncID)
                            
                        } catch {
                            context.rollback()
                            Self.log("❌ Core Data error syncing \(collectionName) record \(record): \(error.localizedDescription)",
                                     level: .error,
                                     collection: collectionName,
                                     syncID: syncID)
                            errorCount += 1
                        }
                    }
                    
                } catch {
                    Self.log("❌ Error fetching Firestore doc: \(record) → \(error.localizedDescription)",
                             level: .error,
                             collection: collectionName,
                             syncID: syncID)
                    errorCount += 1
                }
            }
            
            await context.perform {
                if context.hasChanges {
                    do {
                        try context.save()
                        Self.log("💾 Final Core Data save for \(collectionName).")
                    } catch {
                        Self.log("❌ Error performing final save for \(collectionName): \(error.localizedDescription)")
                    }
                }
            }
            
            return (downloadedCount, errorCount)
        }.value
        
        var summary: String
        var toastType: ToastView.ToastType
        
        if result.downloadedCount > 0 && result.errorCount == 0 {
            summary = "✅ Downloaded all \(result.downloadedCount) records"
            toastType = .success
        } else if result.downloadedCount > 0 {
            summary = "⚠️ \(result.downloadedCount) succeeded, \(result.errorCount) failed"
            toastType = .info
        } else {
            summary = "❌ All \(records.count) downloads failed"
            toastType = .error
        }
        
        _ = summary
        _ = toastType
        
        Self.log("🏁 Firestore sync complete for \(collectionName): \(result.downloadedCount) succeeded | \(result.errorCount) failed")
    }

    
    // MARK: - Static helpers for Firestore sync
    // ---------------------------
    // PirateIsland
    // ---------------------------
    private static func syncPirateIslandStatic(
        docSnapshot: DocumentSnapshot,
        context: NSManagedObjectContext
    ) throws {
        let data = docSnapshot.data() ?? [:]
        guard !data.isEmpty else { return }

        // 🔍 Handle both "islandName" & "name", and "islandLocation" & "location"
        let islandName = data["islandName"] as? String ?? data["name"] as? String
        let islandLocation = data["islandLocation"] as? String ?? data["location"] as? String

        guard let name = islandName, let location = islandLocation else {
            FirestoreSyncManager.log("⚠️ Missing required fields for PirateIsland \(docSnapshot.documentID). Skipping.", level: .error, collection: "pirateIslands")
            return
        }

        // --- Safe data extraction
        let country = data["country"] as? String
        let createdByUserId = data["createdByUserId"] as? String
        let lastModifiedByUserId = data["lastModifiedByUserId"] as? String
        let createdTimestamp = (data["createdTimestamp"] as? Timestamp)?.dateValue() ?? Date()
        let lastModifiedTimestamp = (data["lastModifiedTimestamp"] as? Timestamp)?.dateValue() ?? Date()
        let latitude = data["latitude"] as? Double ?? 0.0
        let longitude = data["longitude"] as? Double ?? 0.0
        let gymWebsiteString = data["gymWebsite"] as? String
        let gymWebsite = gymWebsiteString != nil ? URL(string: gymWebsiteString!) : nil

        // --- Fetch or create local record
        let fetchRequest = PirateIsland.fetchRequest() as! NSFetchRequest<PirateIsland>
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", docSnapshot.documentID)
        let results = try context.fetch(fetchRequest)
        let island = results.first ?? PirateIsland(context: context)

        // --- Update Core Data fields
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

        try context.save()
        FirestoreSyncManager.log("✅ Synced pirateIslands record: \(docSnapshot.documentID)", level: .success, collection: "pirateIslands")
    }


    
    // ---------------------------
    // Review
    // ---------------------------
    private static func syncReviewStatic(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        let fetchRequest = Review.fetchRequest() as! NSFetchRequest<Review>
        
        guard let uuid = UUID(uuidString: docSnapshot.documentID) else {
            Self.log(
                "Invalid UUID string for Review: \(docSnapshot.documentID)",
                level: .error,
                collection: "Review"
            )
            return
        }
        
        fetchRequest.predicate = NSPredicate(format: "reviewID == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1
        
        var review: Review?
        
        do {
            review = try context.fetch(fetchRequest).first
        } catch {
            Self.log(
                "Error fetching Review by ID: \(error.localizedDescription)",
                level: .error,
                collection: "Review"
            )
        }
        
        if review == nil {
            review = Review(context: context)
            review?.reviewID = uuid
            Self.log(
                "Creating new Review with ID: \(docSnapshot.documentID)",
                level: .creating,
                collection: "Review"
            )
        } else {
            Self.log(
                "Updating existing Review with ID: \(docSnapshot.documentID)",
                level: .updating,
                collection: "Review"
            )
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

            Self.log(
                "Synced Review \(docSnapshot.documentID)",
                level: .sync,
                collection: "Review"
            )
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
            Self.log(
                "Error fetching MatTime by ID: \(error.localizedDescription)",
                level: .error,
                collection: "MatTime"
            )
        }

        if matTime == nil {
            matTime = MatTime(context: context)
            if let uuid = UUID(uuidString: docSnapshot.documentID) {
                matTime?.id = uuid
                Self.log(
                    "Creating new MatTime with ID: \(docSnapshot.documentID)",
                    level: .creating,
                    collection: "MatTime"
                )
            }
        } else {
            Self.log(
                "Updating existing MatTime with ID: \(docSnapshot.documentID)",
                level: .updating,
                collection: "MatTime"
            )
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

            // Link AppDayOfWeek
            if let appDayOfWeekRef = docSnapshot.get("appDayOfWeek") as? DocumentReference {
                let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "appDayOfWeekID == %@", appDayOfWeekRef.documentID)
                fetchRequest.fetchLimit = 1
                if let appDayOfWeek = try? context.fetch(fetchRequest).first {
                    mt.appDayOfWeek = appDayOfWeek
                }
            }

            Self.log(
                "Synced MatTime \(docSnapshot.documentID)",
                level: .sync,
                collection: "MatTime"
            )
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
            Self.log(
                "Error fetching AppDayOfWeek by ID: \(error.localizedDescription)",
                level: .error,
                collection: "AppDayOfWeek"
            )
        }

        if ado == nil {
            ado = AppDayOfWeek(context: context)
            ado?.appDayOfWeekID = docSnapshot.documentID
            Self.log(
                "Creating new AppDayOfWeek with ID: \(docSnapshot.documentID)",
                level: .creating,
                collection: "AppDayOfWeek"
            )
        } else {
            Self.log(
                "Updating existing AppDayOfWeek with ID: \(docSnapshot.documentID)",
                level: .updating,
                collection: "AppDayOfWeek"
            )
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

            Self.log(
                "Synced AppDayOfWeek \(docSnapshot.documentID)",
                level: .sync,
                collection: "AppDayOfWeek"
            )
        }
    }

    
    
    // MARK: - Helper functions
    private func syncPirateIsland(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var pirateIsland = fetchPirateIslandByID(docSnapshot.documentID, in: context)
        
        if pirateIsland == nil {
            pirateIsland = PirateIsland(context: context)
            pirateIsland?.islandID = UUID(uuidString: docSnapshot.documentID)
            Self.log(
                "Creating new PirateIsland with ID: \(docSnapshot.documentID)",
                level: .creating,
                collection: "pirateIslands"
            )
        } else {
            Self.log(
                "Updating existing PirateIsland with ID: \(docSnapshot.documentID)",
                level: .updating,
                collection: "pirateIslands"
            )
        }
        
        if let pi = pirateIsland {
            // ✅ FIX: Added nil-coalescing (??) for non-optional properties (islandName, createdTimestamp)
            pi.islandName = docSnapshot.get("name") as? String ?? "Unknown Island"
            pi.islandLocation = docSnapshot.get("location") as? String
            pi.country = docSnapshot.get("country") as? String
            pi.createdByUserId = docSnapshot.get("createdByUserId") as? String
            pi.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue() ?? Date()
            
            if let urlString = docSnapshot.get("gymWebsite") as? String {
                pi.gymWebsite = URL(string: urlString)
            }
            
            pi.latitude = docSnapshot.get("latitude") as? Double ?? 0.0
            pi.longitude = docSnapshot.get("longitude") as? Double ?? 0.0
            pi.lastModifiedByUserId = docSnapshot.get("lastModifiedByUserId") as? String
            pi.lastModifiedTimestamp = (docSnapshot.get("lastModifiedTimestamp") as? Timestamp)?.dateValue()
            
            Self.log(
                "Synced PirateIsland \(docSnapshot.documentID)",
                level: .sync,
                collection: "pirateIslands"
            )
        }
    }
    
    private func syncReview(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var review = fetchReviewByID(docSnapshot.documentID, in: context)
        
        if review == nil {
            review = Review(context: context)
            if let uuid = UUID(uuidString: docSnapshot.documentID) {
                review?.reviewID = uuid
            } else {
                Self.log(
                    "Invalid UUID for Review: \(docSnapshot.documentID)",
                    level: .error,
                    collection: "reviews"
                )
            }
            Self.log(
                "Creating new Review with ID: \(docSnapshot.documentID)",
                level: .creating,
                collection: "reviews"
            )
        } else {
            Self.log(
                "Updating existing Review with ID: \(docSnapshot.documentID)",
                level: .updating,
                collection: "reviews"
            )
        }
        
        if let r = review {
            r.stars = docSnapshot.get("stars") as? Int16 ?? 0
            r.review = docSnapshot.get("review") as? String ?? ""
            r.userName = docSnapshot.get("userName") as? String ?? docSnapshot.get("name") as? String ?? "Anonymous"
            r.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue() ?? Date()
            
            if let islandIDString = docSnapshot.get("islandID") as? String,
               let island = fetchPirateIslandByID(islandIDString, in: context) {
                r.island = island
                Self.log(
                    "Linked Review \(docSnapshot.documentID) to PirateIsland \(island.islandID?.uuidString ?? "")",
                    level: .sync,
                    collection: "reviews"
                )
            }
        }
    }


    
    private func syncMatTime(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var matTime = fetchMatTimeByID(docSnapshot.documentID, in: context)
        
        if matTime == nil {
            matTime = MatTime(context: context)
            if let uuid = UUID(uuidString: docSnapshot.documentID) {
                matTime?.id = uuid
                Self.log(
                    "Creating new MatTime with ID: \(docSnapshot.documentID)",
                    level: .creating,
                    collection: "MatTime"
                )
            }
        } else {
            Self.log(
                "Updating existing MatTime with ID: \(docSnapshot.documentID)",
                level: .updating,
                collection: "MatTime"
            )
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
                Self.log(
                    "Linked MatTime \(docSnapshot.documentID) to AppDayOfWeek \(appDayOfWeek.appDayOfWeekID ?? "")",
                    level: .sync,
                    collection: "MatTime"
                )
            }
        }
    }

    
    private func syncAppDayOfWeek(docSnapshot: DocumentSnapshot, context: NSManagedObjectContext) throws {
        var ado = fetchAppDayOfWeekByID(docSnapshot.documentID, in: context)
        if ado == nil {
            ado = AppDayOfWeek(context: context)
            ado?.appDayOfWeekID = docSnapshot.documentID
            Self.log(
                "Creating new AppDayOfWeek with ID: \(docSnapshot.documentID)",
                level: .creating,
                collection: "AppDayOfWeek"
            )
        } else {
            Self.log(
                "Updating existing AppDayOfWeek with ID: \(docSnapshot.documentID)",
                level: .updating,
                collection: "AppDayOfWeek"
            )
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
                    Self.log(
                        "Created linked PirateIsland with ID: \(pirateIslandID)",
                        level: .creating,
                        collection: "pirateIslands"
                    )
                }
            }
            
            // Link MatTimes
            if let matTimesArray = docSnapshot.get("matTimes") as? [String] {
                for matTimeID in matTimesArray {
                    if let matTime = fetchMatTimeByID(matTimeID, in: context) {
                        ado.addToMatTimes(matTime)
                        Self.log(
                            "Linked MatTime \(matTimeID) to AppDayOfWeek \(ado.appDayOfWeekID ?? "")",
                            level: .sync,
                            collection: "MatTime"
                        )
                    }
                }
            }
        }
    }


    
    private func fetchPirateIslandByID(_ id: String, in context: NSManagedObjectContext) -> PirateIsland? {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()

        guard let uuid = UUID(uuidString: id) else {
            Self.log(
                "Invalid UUID string: \(id)",
                level: .error,
                collection: "pirateIslands"
            )
            return nil
        }

        fetchRequest.predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            Self.log(
                "Error fetching PirateIsland by ID: \(error.localizedDescription)",
                level: .error,
                collection: "pirateIslands"
            )
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
            Self.log(
                "Error fetching MatTime by ID: \(id): \(error.localizedDescription)",
                level: .error,
                collection: "MatTime"
            )
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
            Self.log(
                "Error fetching AppDayOfWeek with ID \(id): \(error.localizedDescription)",
                level: .error,
                collection: "AppDayOfWeek"
            )
            return nil
        }
    }


    // Add this helper function somewhere in your class
    private func fetchReviewByID(_ id: String, in context: NSManagedObjectContext) -> Review? {
        // Explicitly cast the fetch request to NSFetchRequest<Review>
        let fetchRequest = Review.fetchRequest() as! NSFetchRequest<Review>

        guard let uuid = UUID(uuidString: id) else {
            Self.log(
                "Invalid UUID string for Review: \(id)",
                level: .error,
                collection: "reviews"
            )
            return nil
        }

        fetchRequest.predicate = NSPredicate(format: "reviewID == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            Self.log(
                "Error fetching Review by ID: \(error.localizedDescription)",
                level: .error,
                collection: "reviews"
            )
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
            Self.log(
                "Error syncing AppDayOfWeek records: \(error.localizedDescription)",
                level: .error,
                collection: "AppDayOfWeek"
            )
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
        let context = PersistenceController.shared.container.newBackgroundContext()

        let listener = db.collection(collectionName).addSnapshotListener { snapshot, error in
            if let error = error {
                Self.log("Listener error: \(error.localizedDescription)",
                         level: .error,
                         collection: collectionName)
                return
            }

            guard let snapshot = snapshot else { return }

            for change in snapshot.documentChanges {
                context.perform {
                    handler(change, context)
                    do {
                        try context.save()
                    } catch {
                        Self.log("Error saving context for listener: \(error.localizedDescription)",
                                 level: .error,
                                 collection: collectionName)
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
