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

    private var hasPerformedInitialSync = false


    func startAppSync(force: Bool = false) async {

        guard !isSyncInProgress else {

            FirestoreSyncManager.log(
                "🚫 Sync already in progress — skipping duplicate call.",
                level: .warning
            )

            return
        }


        if hasPerformedInitialSync && !force {

            FirestoreSyncManager.log(
                "✅ Initial sync already done — skipping.",
                level: .info
            )

            return
        }


        isSyncInProgress = true

        defer {

            isSyncInProgress = false

            hasPerformedInitialSync = true
        }


        // ✅ This does NOT block UI
        // because syncInitialFirestoreData is NOT MainActor

        await FirestoreSyncManager.shared.syncInitialFirestoreData()


        await MainActor.run {

            FirestoreSyncManager.shared.startFirestoreListeners()

        }

    }
}


class FirestoreSyncManager {
    
    @MainActor private var initialSyncCompleted = false
    static let shared = FirestoreSyncManager()
    
    func syncInitialFirestoreData() async {

        FirestoreSyncManager.log(
            "🚀 Starting initial Firestore sync",
            level: .sync
        )

        do {

            // ---------------------------------------------------------
            // STEP 1: Ensure collections exist & reconcile
            // ---------------------------------------------------------

            try await createFirestoreCollection()



            // ---------------------------------------------------------
            // STEP 2: Begin ordered downloads
            // ---------------------------------------------------------

            let db = Firestore.firestore()



            // 1️⃣ PirateIslands
            try await downloadCollection(
                db: db,
                name: "pirateIslands"
            )



            // 2️⃣ AppDayOfWeek
            try await downloadCollection(
                db: db,
                name: "AppDayOfWeek"
            )



            // ---------------------------------------------------------
            // HARD BARRIER
            // Wait for Core Data merges
            // ---------------------------------------------------------

            await PersistenceController.shared.waitForBackgroundSaves()



            // 3️⃣ MatTime
            try await downloadCollection(
                db: db,
                name: "MatTime"
            )



            // 4️⃣ Reviews
            try await downloadCollection(
                db: db,
                name: "reviews"
            )



            // ---------------------------------------------------------
            // FINAL HARD BARRIER
            // ---------------------------------------------------------

            await PersistenceController.shared.waitForBackgroundSaves()



            // ---------------------------------------------------------
            // SAFE UI LOGGING
            // ---------------------------------------------------------

            await MainActor.run {

                FirestoreSyncManager.log(
                    "🧩 Core Data graph fully merged and stable",
                    level: .finished
                )

            }



            FirestoreSyncManager.log(
                "✅ Initial Firestore sync complete",
                level: .finished
            )
            
            await MainActor.run {
                initialSyncCompleted = true
            }
        }
        catch {

            FirestoreSyncManager.log(
                "❌ Initial Firestore sync failed: \(error.localizedDescription)",
                level: .error
            )

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
                _ = await Task { [localRecords] in
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
        
        let (uploadedCount, errorCount) = await Task { () -> (Int, Int) in
            var uploaded = 0
            var errors = 0
            
            for record in records {
                var localRecord: AnyObject?
                
                if collectionName == "pirateIslands" {
                    // PirateIsland now uses String ID
                    localRecord = try? await PersistenceController.shared.fetchLocalRecord(
                        forCollection: collectionName,
                        recordId: record
                    )
                } else {
                    // Other entities still use UUID
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
                    localRecord = try? await PersistenceController.shared.fetchLocalRecord(
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
                
                // Map Core Data object to Firestore dictionary
                var recordData: [String: Any] = [:]
                switch collectionName {
                case "pirateIslands":
                    guard let pirateIsland = localRecord as? PirateIsland else { continue }
                    recordData = [
                        "id": pirateIsland.islandID ?? "",
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
                        "islandID": review.island?.islandID ?? ""
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
                        "createdTimestamp": matTime.createdTimestamp ?? Date()
                    ]
                    if let adoID = matTime.appDayOfWeek?.appDayOfWeekID {
                        recordData["appDayOfWeek"] = Firestore.firestore()
                            .collection("AppDayOfWeek")
                            .document(adoID)
                    }
                    
                case "AppDayOfWeek":
                    guard let appDayOfWeek = localRecord as? AppDayOfWeek else { continue }
                    let id = appDayOfWeek.appDayOfWeekID ?? ""
                    recordData = [
                        "id": id,
                        "appDayOfWeekID": id,
                        "day": appDayOfWeek.day,
                        "name": appDayOfWeek.name ?? "",
                        "createdTimestamp": appDayOfWeek.createdTimestamp ?? Date()
                    ]
                    
                default:
                    continue
                }
                
                // Use record (String) directly as Firestore document ID
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
    private func syncRecords(
        localRecords: [String],
        firestoreRecords: [String],
        collectionName: String
    ) async {

        // Normalize for comparison
        let normalizedFirestoreRecords =
            firestoreRecords.map {
                $0.replacingOccurrences(of: "-", with: "")
            }

        let normalizedLocalRecords =
            localRecords.map {
                $0.replacingOccurrences(of: "-", with: "")
            }

        // Identify local records missing in Firestore
        let localRecordsNotInFirestore =
            localRecords.filter {

                !normalizedFirestoreRecords.contains(
                    $0.replacingOccurrences(of: "-", with: "")
                )
            }

        // Identify Firestore records missing locally
        let firestoreRecordsNotInLocal =
            firestoreRecords.filter {

                !normalizedLocalRecords.contains(
                    $0.replacingOccurrences(of: "-", with: "")
                )
            }


        // MARK: Sync summary

        Self.log(
        """
        🔄 Starting sync for \(collectionName):
           • 🆙 \(localRecordsNotInFirestore.count) local → Firestore
           • 📥 \(firestoreRecordsNotInLocal.count) Firestore → Core Data
        """,
        level: .sync,
        collection: collectionName
        )



        // MARK: Delete orphaned local

        if !localRecordsNotInFirestore.isEmpty {

            Self.log(
                "🗑️ Deleting \(localRecordsNotInFirestore.count) orphaned local records",
                level: .warning,
                collection: collectionName
            )

            await deleteLocalRecords(
                collectionName: collectionName,
                records: localRecordsNotInFirestore
            )
        }
        else {

            Self.log(
                "✅ No orphaned local records",
                level: .success,
                collection: collectionName
            )
        }



        // MARK: Download missing Firestore records

        if !firestoreRecordsNotInLocal.isEmpty {

            Self.log(
                "⬇️ Downloading \(firestoreRecordsNotInLocal.count) records from Firestore",
                level: .download,
                collection: collectionName
            )

            await downloadFirestoreRecordsToLocal(
                collectionName: collectionName,
                records: firestoreRecordsNotInLocal
            )
        }
        else {

            Self.log(
                "✅ No missing Firestore records",
                level: .success,
                collection: collectionName
            )
        }



        // MARK: Completion summary

        Self.log(
        """
        🏁 Finished sync for \(collectionName)
           • Deleted: \(localRecordsNotInFirestore.count)
           • Downloaded: \(firestoreRecordsNotInLocal.count)
        """,
        level: .finished,
        collection: collectionName
        )



        // ============================================================
        // ⭐ CRITICAL FIX: WAIT FOR CORE DATA MERGE
        // ============================================================

        await PersistenceController.shared.waitForBackgroundSaves()



        // ============================================================
        // MARK: FINAL INTEGRITY CHECK
        // ============================================================

        let refreshedLocalRecords =
            (try? await PersistenceController.shared
                .fetchLocalRecords(forCollection: collectionName)) ?? []



        let finalLocalCount =
            refreshedLocalRecords.count


        let initialFirestoreCount =
            firestoreRecords.count



        let refreshedLocalNormalized =
            refreshedLocalRecords.map {
                $0.replacingOccurrences(of: "-", with: "")
            }


        let firestoreNormalized =
            firestoreRecords.map {
                $0.replacingOccurrences(of: "-", with: "")
            }



        let missingLocalFinal =
            firestoreRecords.filter {

                !refreshedLocalNormalized.contains(
                    $0.replacingOccurrences(of: "-", with: "")
                )
            }



        let missingRemoteFinal =
            refreshedLocalRecords.filter {

                !firestoreNormalized.contains(
                    $0.replacingOccurrences(of: "-", with: "")
                )
            }



        let countDifference =
            abs(finalLocalCount - initialFirestoreCount)



        Self.log(
            "Integrity check → local=\(finalLocalCount), firestore=\(initialFirestoreCount)",
            level: .sync,
            collection: collectionName
        )



        // MARK: Toast + logging

        DispatchQueue.main.async {

            if countDifference > 0 {

                Self.log(
                """
                ⚠️ Needs sync:
                   • Missing locally: \(missingLocalFinal.count)
                   • Missing in cloud: \(missingRemoteFinal.count)
                """,
                level: .warning,
                collection: collectionName
                )


                if !missingLocalFinal.isEmpty {

                    Self.log(
                        "⬇️ Missing locally IDs: \(missingLocalFinal)",
                        level: .warning,
                        collection: collectionName
                    )
                }


                if !missingRemoteFinal.isEmpty {

                    Self.log(
                        "⬆️ Missing in Firestore IDs: \(missingRemoteFinal)",
                        level: .warning,
                        collection: collectionName
                    )
                }



                var toastMessage = "Needs sync"


                if !missingLocalFinal.isEmpty {

                    toastMessage += "\n⬇️ Missing locally: \(missingLocalFinal.count)"
                }


                if !missingRemoteFinal.isEmpty {

                    toastMessage += "\n⬆️ Missing in cloud: \(missingRemoteFinal.count)"
                }



                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: toastMessage,
                    type: .info,
                    isPersistent: false
                )

            }
            else {

                Self.log(
                    "✅ Integrity check passed",
                    level: .success,
                    collection: collectionName
                )



                let action =
                    localRecordsNotInFirestore.isEmpty &&
                    firestoreRecordsNotInLocal.isEmpty
                    ? "Already Synced"
                    : "Synced successfully"



                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: action,
                    type: .success,
                    isPersistent: false
                )
            }
        }
    }
    
    private func deleteLocalRecords(
        collectionName: String,
        records: [String]
    ) async {

        for record in records {

            await PersistenceController.shared.deleteLocalRecord(
                forCollection: collectionName,
                recordId: record
            )

            Self.log(
                "🗑️ Deleted local orphaned record \(record)",
                level: .warning,
                collection: collectionName
            )
        }
    }

    
    private func downloadFirestoreRecordsToLocal(
        collectionName: String,
        records: [String]
    ) async {

        guard !records.isEmpty else {
            Self.log("⚠️ No Firestore records found to download for \(collectionName).")
            return
        }

        Self.log(
            "📥 Starting Firestore → Core Data sync for **\(collectionName)** (\(records.count) total records)"
        )

        // ✅ FIX 1: correct actor-safe context creation
        let context = await PersistenceController.shared.newFirestoreContext()

        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)

        var downloadedCount = 0
        var errorCount = 0

        let batchSaveInterval = 10
        let syncID = String(UUID().uuidString.prefix(8))

        for record in records {

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
                        Self.log("⚠️ Firestore document not found: \(record)",
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

                switch collectionName {

                case "pirateIslands":
                    await Self.syncPirateIslandStatic(docSnapshot: docSnapshot, context: context)

                case "reviews":
                    await Self.syncReviewStatic(docSnapshot: docSnapshot, context: context)

                case "MatTime":
                    await Self.syncMatTimeStatic(docSnapshot: docSnapshot, context: context)

                case "AppDayOfWeek":
                    await Self.syncAppDayOfWeekStatic(docSnapshot: docSnapshot, context: context)

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

                // ✅ FIX 2: capture safe constants
                let currentCount = downloadedCount

                await context.perform {

                    guard currentCount % batchSaveInterval == 0 else { return }
                    guard context.hasChanges else { return }

                    do {

                        try context.save()

                        Task { @MainActor in
                            Self.log("💾 Intermediate save after \(currentCount)",
                                     level: .info,
                                     collection: collectionName,
                                     syncID: syncID)
                        }

                    } catch {

                        context.rollback()

                        Task { @MainActor in
                            Self.log("❌ Intermediate save error: \(error.localizedDescription)",
                                     level: .error,
                                     collection: collectionName,
                                     syncID: syncID)
                        }
                    }
                }

            } catch {

                errorCount += 1

                await MainActor.run {
                    Self.log("❌ Firestore fetch error: \(record) → \(error.localizedDescription)",
                             level: .error,
                             collection: collectionName,
                             syncID: syncID)
                }
            }
        }

        // ✅ FIX 3: safe final save
        await context.perform {

            guard context.hasChanges else { return }

            do {

                try context.save()

                Task { @MainActor in
                    Self.log("💾 Final Core Data save complete",
                             level: .info,
                             collection: collectionName,
                             syncID: syncID)
                }

            } catch {

                context.rollback()

                Task { @MainActor in
                    Self.log("❌ Final save failed: \(error.localizedDescription)",
                             level: .error,
                             collection: collectionName,
                             syncID: syncID)
                }
            }
        }

        // ✅ FIX 4: capture constants for final log
        let finalDownloaded = downloadedCount
        let finalErrors = errorCount

        await MainActor.run {

            Self.log(
                "🏁 Firestore sync complete for \(collectionName): \(finalDownloaded) succeeded | \(finalErrors) failed",
                level: finalErrors == 0 ? .finished : .warning,
                collection: collectionName,
                syncID: syncID
            )
        }

        await PersistenceController.shared.waitForBackgroundSaves()
    }

    
    // MARK: - Static helpers for Firestore sync
    // ---------------------------
    // PirateIsland
    // ---------------------------
    private static func syncPirateIslandStatic(
        docSnapshot: DocumentSnapshot,
        context: NSManagedObjectContext
    ) async {

        let data = docSnapshot.data() ?? [:]
        guard !data.isEmpty else { return }

        let islandName =
            data["islandName"] as? String
            ?? data["name"] as? String

        let islandLocation =
            data["islandLocation"] as? String
            ?? data["location"] as? String

        guard let name = islandName,
              let location = islandLocation
        else {

            await MainActor.run {
                FirestoreSyncManager.log(
                    "⚠️ Missing required fields for PirateIsland \(docSnapshot.documentID). Skipping.",
                    level: .error,
                    collection: "pirateIslands"
                )
            }

            return
        }

        let country =
            data["country"] as? String

        let createdByUserId =
            data["createdByUserId"] as? String

        let lastModifiedByUserId =
            data["lastModifiedByUserId"] as? String

        let createdTimestamp =
            (data["createdTimestamp"] as? Timestamp)?
            .dateValue()
            ?? Date()

        let lastModifiedTimestamp =
            (data["lastModifiedTimestamp"] as? Timestamp)?
            .dateValue()
            ?? Date()

        let latitude =
            data["latitude"] as? Double ?? 0

        let longitude =
            data["longitude"] as? Double ?? 0

        let gymWebsite =
            (data["gymWebsite"] as? String)
            .flatMap(URL.init)

        // ✅ FIX: Use async perform
        await context.perform {

            let fetchRequest: NSFetchRequest<PirateIsland> =
                PirateIsland.fetchRequest()

            fetchRequest.predicate =
                NSPredicate(
                    format: "islandID == %@",
                    docSnapshot.documentID
                )

            fetchRequest.fetchLimit = 1

            do {

                let island =
                    try context.fetch(fetchRequest).first
                    ?? PirateIsland(context: context)

                island.islandID =
                    docSnapshot.documentID

                island.islandName =
                    name

                island.islandLocation =
                    location

                island.country =
                    country

                island.createdByUserId =
                    createdByUserId

                island.createdTimestamp =
                    createdTimestamp

                island.lastModifiedByUserId =
                    lastModifiedByUserId

                island.lastModifiedTimestamp =
                    lastModifiedTimestamp

                island.latitude =
                    latitude

                island.longitude =
                    longitude

                island.gymWebsite =
                    gymWebsite

                guard context.hasChanges else {

                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "ℹ️ No changes detected for PirateIsland \(docSnapshot.documentID)",
                            level: .info,
                            collection: "pirateIslands"
                        )
                    }

                    return
                }

                Task { @MainActor in
                    FirestoreSyncManager.log(
                        "✅ Prepared pirateIslands record: \(docSnapshot.documentID)",
                        level: .success,
                        collection: "pirateIslands"
                    )
                }

            }
            catch {

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
    ) async {

        await context.perform {

            let data = docSnapshot.data() ?? [:]
            guard !data.isEmpty else { return }

            let documentID = docSnapshot.documentID

            let reviewUUID =
                UUID(uuidString: documentID)
                ?? UUID.fromStringID(documentID)

            // ✅ FIX: explicit cast required in Swift 6
            let fetchRequest =
                Review.fetchRequest() as! NSFetchRequest<Review>

            fetchRequest.predicate =
                NSPredicate(
                    format: "reviewID == %@",
                    reviewUUID as CVarArg
                )

            fetchRequest.fetchLimit = 1

            do {

                let review =
                    try context.fetch(fetchRequest).first
                    ?? Review(context: context)


                // -----------------------
                // Map fields
                // -----------------------

                review.reviewID = reviewUUID

                review.stars =
                    (data["stars"] as? Int16)
                    ?? Int16(data["stars"] as? Int ?? 0)

                review.review =
                    data["review"] as? String ?? ""

                review.userName =
                    data["userName"] as? String
                    ?? data["name"] as? String
                    ?? "Anonymous"

                review.createdTimestamp =
                    (data["createdTimestamp"] as? Timestamp)?
                    .dateValue()
                    ?? Date()


                // -----------------------
                // Relationship
                // -----------------------

                if let islandIDString =
                    data["islandID"] as? String {

                    let islandFetch =
                        PirateIsland.fetchRequest()
                    

                    islandFetch.predicate =
                        NSPredicate(
                            format: "islandID == %@",
                            islandIDString
                        )

                    islandFetch.fetchLimit = 1

                    if let island =
                        try context.fetch(islandFetch).first {

                        review.island = island

                    }
                    else {

                        Task { @MainActor in

                            FirestoreSyncManager.log(
                                "⚠️ Island not found for review \(documentID)",
                                level: .warning,
                                collection: "reviews"
                            )
                        }
                    }
                }


                // -----------------------
                // DO NOT SAVE HERE
                // -----------------------

                if context.hasChanges {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "✅ Prepared Review \(documentID)",
                            level: .success,
                            collection: "reviews"
                        )
                    }

                }
                else {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "ℹ️ No changes for Review \(documentID)",
                            level: .info,
                            collection: "reviews"
                        )
                    }
                }

            }
            catch {

                context.rollback()

                Task { @MainActor in

                    FirestoreSyncManager.log(
                        "❌ Failed preparing Review \(documentID): \(error)",
                        level: .error,
                        collection: "reviews"
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
    ) async {

        await context.perform {

            let docID = docSnapshot.documentID

            let uuid =
                UUID(uuidString: docID)
                ?? UUID.fromStringID(docID)


            // -----------------------
            // Fetch existing or create new
            // -----------------------

            let fetchRequest: NSFetchRequest<MatTime> =
                MatTime.fetchRequest()

            fetchRequest.predicate =
                NSPredicate(
                    format: "id == %@",
                    uuid as CVarArg
                )

            fetchRequest.fetchLimit = 1


            do {

                let matTime =
                    try context.fetch(fetchRequest).first
                    ?? MatTime(context: context)


                matTime.id = uuid


                // -----------------------
                // Map fields
                // -----------------------

                matTime.type =
                    docSnapshot.get("type") as? String

                matTime.time =
                    docSnapshot.get("time") as? String

                matTime.gi =
                    docSnapshot.get("gi") as? Bool ?? false

                matTime.noGi =
                    docSnapshot.get("noGi") as? Bool ?? false

                matTime.openMat =
                    docSnapshot.get("openMat") as? Bool ?? false

                matTime.restrictions =
                    docSnapshot.get("restrictions") as? Bool ?? false

                matTime.restrictionDescription =
                    docSnapshot.get("restrictionDescription") as? String

                matTime.goodForBeginners =
                    docSnapshot.get("goodForBeginners") as? Bool ?? false

                matTime.kids =
                    docSnapshot.get("kids") as? Bool ?? false

                matTime.createdTimestamp =
                    (docSnapshot.get("createdTimestamp") as? Timestamp)?
                    .dateValue()


                // -----------------------
                // Resolve relationship safely
                // -----------------------

                guard let appDayRef =
                    docSnapshot.get("appDayOfWeek") as? DocumentReference
                else {

                    context.rollback()

                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "❌ Aborting MatTime — missing appDayOfWeek reference for \(docID)",
                            level: .error,
                            collection: "MatTime"
                        )
                    }

                    return
                }


                let appDayID =
                    appDayRef.documentID


                let adoFetch: NSFetchRequest<AppDayOfWeek> =
                    AppDayOfWeek.fetchRequest()

                adoFetch.predicate =
                    NSPredicate(
                        format: "appDayOfWeekID == %@",
                        appDayID
                    )

                adoFetch.fetchLimit = 1


                guard let appDay =
                    try context.fetch(adoFetch).first
                else {

                    context.rollback()

                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "❌ Aborting MatTime — parent AppDayOfWeek missing (\(appDayID))",
                            level: .error,
                            collection: "MatTime"
                        )
                    }

                    return
                }


                matTime.appDayOfWeek = appDay


                // -----------------------
                // DO NOT SAVE HERE
                // Save handled by batching system
                // -----------------------

                if context.hasChanges {

                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "✅ Prepared MatTime \(docID)",
                            level: .success,
                            collection: "MatTime"
                        )
                    }

                }
                else {

                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "ℹ️ No changes for MatTime \(docID)",
                            level: .info,
                            collection: "MatTime"
                        )
                    }
                }

            }
            catch {

                context.rollback()

                Task { @MainActor in
                    FirestoreSyncManager.log(
                        "❌ Failed preparing MatTime \(docID): \(error.localizedDescription)",
                        level: .error,
                        collection: "MatTime"
                    )
                }
            }
        }
    }
    
    // ---------------------------
    // AppDayOfWeek
    // ---------------------------
    private static func syncAppDayOfWeekStatic(
        docSnapshot: DocumentSnapshot,
        context: NSManagedObjectContext
    ) async {

        #if DEBUG
        if context.concurrencyType != .privateQueueConcurrencyType {
            print("❌ ERROR: syncAppDayOfWeekStatic called with MAIN context!")
        }
        #endif

        await context.perform {

            let fetchRequest: NSFetchRequest<AppDayOfWeek> =
                AppDayOfWeek.fetchRequest()

            let docID = docSnapshot.documentID

            let uuidVersion =
                UUID.fromStringID(docID).uuidString


            fetchRequest.predicate =
                NSPredicate(
                    format: "appDayOfWeekID == %@ OR appDayOfWeekID == %@",
                    docID,
                    uuidVersion
                )

            fetchRequest.fetchLimit = 1


            do {

                // Fetch existing or create new
                let ado =
                    try context.fetch(fetchRequest).first
                    ?? {
                        let new =
                            AppDayOfWeek(context: context)

                        new.appDayOfWeekID = docID

                        return new
                    }()



                // -----------------------
                // Required field
                // -----------------------

                guard let day =
                    docSnapshot.get("day") as? String,
                    !day.isEmpty
                else {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "❌ Invalid AppDayOfWeek (missing day)",
                            level: .error,
                            collection: "AppDayOfWeek"
                        )
                    }

                    return
                }

                ado.day = day



                // -----------------------
                // Name
                // -----------------------

                if let nameFromFS =
                    docSnapshot.get("name") as? String {

                    ado.name = nameFromFS

                }
                else if let islandName =
                    (docSnapshot.get("pIsland") as? [String: Any])?["islandName"] as? String {

                    ado.name =
                        "\(islandName) - \(day)"
                }
                else {

                    ado.name = day
                }



                // -----------------------
                // Timestamp
                // -----------------------

                if let ts =
                    docSnapshot.get("createdTimestamp") as? Timestamp {

                    ado.createdTimestamp =
                        ts.dateValue()

                }
                else if ado.createdTimestamp == nil {

                    ado.createdTimestamp = Date()
                }



                // -----------------------
                // PirateIsland link
                // -----------------------

                if let pIslandData =
                    docSnapshot.get("pIsland") as? [String: Any],

                   let pirateIslandID =
                    pIslandData["islandID"] as? String
                {

                    let islandFetch:
                        NSFetchRequest<PirateIsland> =
                            PirateIsland.fetchRequest()

                    islandFetch.predicate =
                        NSPredicate(
                            format: "islandID == %@",
                            pirateIslandID
                        )

                    islandFetch.fetchLimit = 1


                    let island =
                        try context.fetch(islandFetch).first
                        ?? {

                            let newIsland =
                                PirateIsland(context: context)

                            newIsland.islandID =
                                pirateIslandID

                            newIsland.islandName =
                                pIslandData["islandName"] as? String
                                ?? pIslandData["name"] as? String

                            newIsland.islandLocation =
                                pIslandData["islandLocation"] as? String
                                ?? pIslandData["location"] as? String

                            newIsland.country =
                                pIslandData["country"] as? String

                            newIsland.createdTimestamp =
                                (pIslandData["createdTimestamp"] as? Timestamp)?
                                .dateValue()
                                ?? Date()

                            newIsland.latitude =
                                pIslandData["latitude"] as? Double ?? 0

                            newIsland.longitude =
                                pIslandData["longitude"] as? Double ?? 0

                            if let urlString =
                                pIslandData["gymWebsite"] as? String {

                                newIsland.gymWebsite =
                                    URL(string: urlString)
                            }

                            return newIsland

                        }()

                    ado.pIsland = island
                }



                // -----------------------
                // DO NOT SAVE HERE
                // Save handled by batching system
                // -----------------------

                if context.hasChanges {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "✅ Prepared AppDayOfWeek \(docID) for save",
                            level: .success,
                            collection: "AppDayOfWeek"
                        )
                    }

                }
                else {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "ℹ️ No changes for AppDayOfWeek \(docID)",
                            level: .info,
                            collection: "AppDayOfWeek"
                        )
                    }

                }

            }
            catch {

                context.rollback()

                Task { @MainActor in

                    FirestoreSyncManager.log(
                        "❌ Failed syncing AppDayOfWeek: \(error)",
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
        
        guard initialSyncCompleted else {
            
            Self.log(
                "⏳ Prevented listener start — initial sync not completed yet",
                level: .warning
            )
            
            return
        }
        
        guard Self.listenerRegistrations.isEmpty else {
            
            Self.log(
                "⚠️ Listeners already running — skipping duplicate start",
                level: .warning
            )
            
            return
        }
        
        Self.log(
            "Starting Firestore listeners for all collections",
            level: .updating
        )
        
        listenToCollection(
            "pirateIslands",
            handler: Self.handlePirateIslandChange
        )
        
        listenToCollection(
            "reviews",
            handler: Self.handleReviewChange
        )
        
        listenToCollection(
            "AppDayOfWeek",
            handler: Self.handleAppDayOfWeekChange
        )
        
        listenToCollection(
            "MatTime",
            handler: Self.handleMatTimeChange
        )
    }
    
    
    
    func stopFirestoreListeners() {
        
        Self.log(
            "Stopping all Firestore listeners",
            level: .warning
        )
        
        for registration in Self.listenerRegistrations {
            
            registration.remove()
        }
        
        Self.listenerRegistrations.removeAll()
    }
    
    
    
    // MARK: - Generic listener
    @MainActor
    private func listenToCollection(
        _ collectionName: String,
        handler: @escaping (
            DocumentChange,
            NSManagedObjectContext
        ) async -> Void
    ) {
        
        let db = Firestore.firestore()
        
        let listener =
        db.collection(collectionName)
            .addSnapshotListener { [weak self] snapshot, error in
                
                guard self != nil else { return }
                
                if let error {
                    
                    Task { @MainActor in
                        
                        Self.log(
                            "Listener error: \(error.localizedDescription)",
                            level: .error,
                            collection: collectionName
                        )
                    }
                    
                    return
                }
                
                guard let snapshot else { return }
                
                for change in snapshot.documentChanges {
                    
                    Task(priority: .utility) {
                        
                        // ✅ CRITICAL FIX #1
                        // Create NEW context per change
                        let backgroundContext =
                        PersistenceController.shared
                            .newFirestoreContext()
                        
                        // ✅ CRITICAL FIX #2
                        // Ensure parent relationships merged first
                        await PersistenceController.shared
                            .waitForBackgroundSaves()
                        
                        // ✅ Perform sync
                        await handler(
                            change,
                            backgroundContext
                        )
                        
                        // ✅ Save safely
                        await backgroundContext.perform {
                            
                            do {
                                
                                if backgroundContext.hasChanges {
                                    
                                    try backgroundContext.save()
                                    
                                    Task { @MainActor in
                                        
                                        Self.log(
                                            "✅ Listener saved change \(change.document.documentID)",
                                            level: .success,
                                            collection: collectionName
                                        )
                                    }
                                }
                                
                            }
                            catch {
                                
                                backgroundContext.rollback()
                                
                                Task { @MainActor in
                                    
                                    Self.log(
                                        "❌ Listener save failed: \(error.localizedDescription)",
                                        level: .error,
                                        collection: collectionName
                                    )
                                }
                            }
                        }
                    }
                }
            }
        
        // Store listener safely
        Self.listenerRegistrations.append(listener)
    }
}


extension FirestoreSyncManager {
    
    // MARK: - Handlers for document changes
    
    static func handlePirateIslandChange(
        _ change: DocumentChange,
        _ context: NSManagedObjectContext
    ) async {
        
        switch change.type {
            
        case .added, .modified:
            
            await syncPirateIslandStatic(
                docSnapshot: change.document,
                context: context
            )
            
        case .removed:
            
            await context.perform {
                
                deleteEntity(
                    ofType: PirateIsland.self,
                    idString: change.document.documentID,
                    keyPath: \.islandID,
                    context: context
                )
                
                do {
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    context.rollback()
                }
            }
        }
    }
    
    
    static func handleReviewChange(
        _ change: DocumentChange,
        _ context: NSManagedObjectContext
    ) async {
        
        switch change.type {
            
        case .added, .modified:
            
            await syncReviewStatic(
                docSnapshot: change.document,
                context: context
            )
            
        case .removed:
            
            await context.perform {
                
                deleteEntity(
                    ofType: Review.self,
                    idString: change.document.documentID,
                    keyPath: \.reviewID,
                    context: context
                )
                
                do {
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    context.rollback()
                }
            }
        }
    }
    
    
    static func handleAppDayOfWeekChange(
        _ change: DocumentChange,
        _ context: NSManagedObjectContext
    ) async {
        
        switch change.type {
            
        case .added, .modified:
            
            await syncAppDayOfWeekStatic(
                docSnapshot: change.document,
                context: context
            )
            
        case .removed:
            
            await context.perform {
                
                deleteEntity(
                    ofType: AppDayOfWeek.self,
                    idString: change.document.documentID,
                    keyPath: \.appDayOfWeekID,
                    context: context
                )
                
                do {
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    context.rollback()
                }
            }
        }
    }
    
    
    static func handleMatTimeChange(
        _ change: DocumentChange,
        _ context: NSManagedObjectContext
    ) async {
        
        switch change.type {
            
        case .added, .modified:
            
            await PersistenceController.shared.waitForBackgroundSaves()
            
            await syncMatTimeStatic(
                docSnapshot: change.document,
                context: context
            )
            
            await context.perform {
                
                do {
                    
                    if context.hasChanges {
                        
                        try context.save()
                        
                        Self.log(
                            "✅ Listener saved MatTime \(change.document.documentID)",
                            level: .success,
                            collection: "MatTime"
                        )
                    }
                    
                } catch {
                    
                    context.rollback()
                    
                    Self.log(
                        "❌ Listener failed saving MatTime \(change.document.documentID): \(error)",
                        level: .error,
                        collection: "MatTime"
                    )
                }
            }
            
            
        case .removed:
            
            await context.perform {
                
                deleteEntity(
                    ofType: MatTime.self,
                    idString: change.document.documentID,
                    keyPath: \.id,
                    context: context
                )
                
                do {
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    context.rollback()
                }
            }
        }
    }
    
    
    // MARK: - Generic delete helper (UUID + String safe)
    
    private static func deleteEntity<T: NSManagedObject, V>(
        ofType type: T.Type,
        idString: String,
        keyPath: KeyPath<T, V>,
        context: NSManagedObjectContext
    ) {
        
        let fetchRequest =
        NSFetchRequest<T>(
            entityName: String(describing: type)
        )
        
        let keyPathString =
        NSExpression(forKeyPath: keyPath).keyPath
        
        
        // ✅ FIX: Support BOTH UUID and String IDs safely
        
        if V.self == UUID.self {
            
            let uuid =
            UUID(uuidString: idString)
            ?? UUID.fromStringID(idString)
            
            fetchRequest.predicate =
            NSPredicate(
                format: "%K == %@",
                keyPathString,
                uuid as CVarArg
            )
            
        }
        else if V.self == String.self {
            
            fetchRequest.predicate =
            NSPredicate(
                format: "%K == %@",
                keyPathString,
                idString
            )
            
        }
        else {
            
            // Unsupported type safeguard
            
            Task { @MainActor in
                
                Self.log(
                    "❌ Unsupported ID type for delete: \(type)",
                    level: .error,
                    collection: String(describing: type)
                )
            }
            
            return
        }
        
        
        fetchRequest.fetchLimit = 1
        
        
        do {
            
            if let object =
                try context.fetch(fetchRequest).first {
                
                context.delete(object)
                
                
                Task { @MainActor in
                    
                    Self.log(
                        "🗑️ Deleted \(type) with ID \(idString)",
                        level: .warning,
                        collection: String(describing: type)
                    )
                }
            }
            else {
                
                Task { @MainActor in
                    
                    Self.log(
                        "ℹ️ Delete skipped — no matching object for ID \(idString)",
                        level: .info,
                        collection: String(describing: type)
                    )
                }
            }
            
        }
        catch {
            
            context.rollback()
            
            Task { @MainActor in
                
                Self.log(
                    "❌ Delete failed for \(type): \(error.localizedDescription)",
                    level: .error,
                    collection: String(describing: type)
                )
            }
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
