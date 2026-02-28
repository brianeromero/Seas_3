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
    
    @MainActor
    private var pirateIslandCache: [String: NSManagedObjectID] = [:]

    @MainActor
    private var appDayCache: [String: NSManagedObjectID] = [:]
    
    func syncInitialFirestoreData() async {
        await MainActor.run {
            pirateIslandCache.removeAll()
            appDayCache.removeAll()
        }
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


            // ✅ NOW THIS IS THE CORRECT PLACE

            let context = await MainActor.run {
                PersistenceController.shared.newFirestoreContext()
            }

            try await repairRelationshipsAndCaches(context: context)

            await context.perform {
                context.reset()
            }

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

        let start = CFAbsoluteTimeGetCurrent()

        let snapshot = try await db.collection(name).getDocuments()

        let fetchTime = CFAbsoluteTimeGetCurrent()

        FirestoreSyncManager.log(
            "📥 Firestore fetch time: \(String(format: "%.3f", fetchTime - start))s (\(snapshot.documents.count) docs)",
            level: .info,
            collection: name
        )

        await downloadFirestoreDocumentsToLocal(
            collectionName: name,
            documents: snapshot.documents
        )

        let end = CFAbsoluteTimeGetCurrent()

        FirestoreSyncManager.log(
            "💾 Core Data sync time: \(String(format: "%.3f", end - fetchTime))s",
            level: .info,
            collection: name
        )

        FirestoreSyncManager.log(
            "🏁 TOTAL sync time: \(String(format: "%.3f", end - start))s",
            level: .finished,
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
    
    private func downloadFirestoreDocumentsToLocal(
        collectionName: String,
        documents: [QueryDocumentSnapshot]
    ) async {

        let context = await MainActor.run {
            PersistenceController.shared.newFirestoreContext()
        }

        do {

            // STEP 1: Sync all objects

            for doc in documents {

                switch collectionName {

                case "pirateIslands":
                    await Self.syncPirateIslandStatic(docSnapshot: doc, context: context)

                case "reviews":
                    await Self.syncReviewStatic(docSnapshot: doc, context: context)

                case "AppDayOfWeek":
                    await Self.syncAppDayOfWeekStatic(docSnapshot: doc, context: context)

                case "MatTime":
                    await Self.syncMatTimeStatic(docSnapshot: doc, context: context)

                default:
                    break
                }
            }


            // STEP 2: Save once

            try await context.perform {

                guard context.hasChanges else { return }

                context.processPendingChanges()

                try context.save()
            }


            // ✅ STEP 3: Reset ONLY (no repair here)

            await context.perform {

                context.refreshAllObjects()

                context.reset()
            }


            FirestoreSyncManager.log(
                "✅ Transaction complete",
                level: .success,
                collection: collectionName
            )

        }
        catch {

            await context.perform {
                context.rollback()
            }

            FirestoreSyncManager.log(
                "❌ Transaction failed: \(error)",
                level: .error,
                collection: collectionName
            )
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


    private func uploadLocalRecordsToFirestore(
        collectionName: String,
        records: [String]
    ) async {

        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)

        Self.log(
            "Starting upload of \(records.count) local \(collectionName) records to Firestore",
            level: .upload,
            collection: collectionName
        )

        guard !records.isEmpty else {

            Self.log(
                "No local \(collectionName) records to upload.",
                level: .info,
                collection: collectionName
            )

            return
        }


        // ✅ FIX: explicitly store Task result first
        let result = Task { () -> (Int, Int) in

            var uploaded = 0
            var errors = 0

            for record in records {

                var localRecord: AnyObject?

                // Fetch local object
                if collectionName == "pirateIslands" {

                    localRecord =
                    try? await PersistenceController.shared.fetchLocalRecord(
                        forCollection: collectionName,
                        recordId: record
                    )

                } else {

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

                    localRecord =
                    try? await PersistenceController.shared.fetchLocalRecord(
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


                // Map data
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

                        recordData["appDayOfWeek"] =
                        Firestore.firestore()
                            .collection("AppDayOfWeek")
                            .document(adoID)
                    }


                case "AppDayOfWeek":

                    guard let appDay = localRecord as? AppDayOfWeek else { continue }

                    let id = appDay.appDayOfWeekID ?? ""

                    recordData = [
                        "id": id,
                        "appDayOfWeekID": id,
                        "day": appDay.day,
                        "name": appDay.name ?? "",
                        "createdTimestamp": appDay.createdTimestamp ?? Date()
                    ]

                    if let islandID = appDay.pIsland?.islandID {

                        recordData["pIsland"] =
                        Firestore.firestore()
                            .collection("pirateIslands")
                            .document(islandID)
                    }


                default:
                    continue
                }


                // Upload
                do {

                    try await collectionRef
                        .document(record)
                        .setData(recordData)

                    uploaded += 1

                    Self.log(
                        "Uploaded local record \(record)",
                        level: .success,
                        collection: collectionName
                    )

                } catch {

                    errors += 1

                    await MainActor.run {

                        ToastThrottler.shared.postToast(
                            for: collectionName,
                            action: "failed upload \(record)",
                            type: .error,
                            isPersistent: true
                        )
                    }

                    Self.log(
                        "Upload failed \(record): \(error.localizedDescription)",
                        level: .error,
                        collection: collectionName
                    )
                }
            }

            return (uploaded, errors)

        }


        // ✅ SAFE destructuring
        let (uploadedCount, errorCount) = await result.value


        let finalLevel: LogLevel =
            errorCount > 0 ? .warning : .finished


        Self.log(
            """
            Finished uploading \(collectionName)
            success: \(uploadedCount)
            failed: \(errorCount)
            """,
            level: finalLevel,
            collection: collectionName
        )
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

        // ✅ ADD THESE LINES RIGHT HERE
        Self.log("🧪 DEBUG LOCAL IDS: \(refreshedLocalRecords)",
                 level: .warning,
                 collection: collectionName)

        Self.log("🧪 DEBUG FIRESTORE IDS: \(firestoreRecords)",
                 level: .warning,
                 collection: collectionName)

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

        guard !records.isEmpty else { return }

        let context = await MainActor.run {
            PersistenceController.shared.newFirestoreContext()
        }

        await context.perform {

            for record in records {

                switch collectionName {

                case "pirateIslands":

                    Self.deleteEntity(
                        ofType: PirateIsland.self,
                        idString: record,
                        keyPath: \.islandID,
                        context: context
                    )


                case "reviews":

                    Self.deleteEntity(
                        ofType: Review.self,
                        idString: record,
                        keyPath: \.reviewID,
                        context: context
                    )


                case "MatTime":

                    Self.deleteEntity(
                        ofType: MatTime.self,
                        idString: record,
                        keyPath: \.id,
                        context: context
                    )


                case "AppDayOfWeek":

                    Self.deleteEntity(
                        ofType: AppDayOfWeek.self,
                        idString: record,
                        keyPath: \.appDayOfWeekID,
                        context: context
                    )


                default:

                    FirestoreSyncManager.log(
                        "❌ Unknown collection \(collectionName)",
                        level: .error,
                        collection: collectionName
                    )
                }
            }


            guard context.hasChanges else { return }


            context.processPendingChanges()


            do {

                try context.save()

                FirestoreSyncManager.log(
                    "💾 Deleted \(records.count) local orphaned records",
                    level: .success,
                    collection: collectionName
                )


                context.reset()
            }
            catch {

                context.rollback()

                FirestoreSyncManager.log(
                    "❌ Failed deleting local records: \(error)",
                    level: .error,
                    collection: collectionName
                )
            }
        }


        await PersistenceController.shared.waitForBackgroundSaves()
    }

    private func downloadFirestoreRecordsToLocal(
        collectionName: String,
        records: [String]
    ) async {

        guard !records.isEmpty else { return }

        let context = await MainActor.run {
            PersistenceController.shared.newFirestoreContext()
        }

        let db = Firestore.firestore()

        let collectionRef = db.collection(collectionName)

        var downloadedCount = 0
        var errorCount = 0

        let chunkSize = 10


        do {

            // =====================================================
            // STEP 1: Process ALL batches first
            // =====================================================

            for chunk in records.chunked(into: chunkSize) {

                let snapshot =
                    try await collectionRef
                        .whereField(
                            FieldPath.documentID(),
                            in: chunk
                        )
                        .getDocuments()


                for docSnapshot in snapshot.documents {

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
                        errorCount += 1
                    }

                    downloadedCount += 1
                }
            }


            // =====================================================
            // STEP 2: SAVE ONCE (transaction)
            // =====================================================

            try await context.perform {

                guard context.hasChanges else { return }

                context.processPendingChanges()

                try context.save()
            }


            // =====================================================
            // STEP 3: Reset LAST
            // =====================================================

            await context.perform {

                context.refreshAllObjects()

                context.reset()
            }


            FirestoreSyncManager.log(
                "🏁 Batch download complete: \(downloadedCount) success, \(errorCount) errors",
                level: .success,
                collection: collectionName
            )

        }
        catch {

            await context.perform {

                context.rollback()
            }

            FirestoreSyncManager.log(
                "❌ Batch transaction failed: \(error)",
                level: .error,
                collection: collectionName
            )
        }


        await PersistenceController.shared.waitForBackgroundSaves()
    }

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


                // =====================================================
                // CRITICAL FIX — Permanent ID
                // =====================================================

                if island.objectID.isTemporaryID {

                    do {

                        try context.obtainPermanentIDs(for: [island])

                    }
                    catch {

                        Task { @MainActor in

                            FirestoreSyncManager.log(
                                "❌ Failed to obtain permanent PirateIsland ID",
                                level: .error,
                                collection: "pirateIslands"
                            )
                        }
                    }
                }


                // =====================================================
                // Map fields
                // =====================================================

                island.islandID = docSnapshot.documentID
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


                // =====================================================
                // Cache SAFE permanent ID
                // =====================================================

                Task { @MainActor in

                    FirestoreSyncManager.shared
                        .pirateIslandCache[docSnapshot.documentID] =
                        island.objectID
                }


                // =====================================================
                // Logging
                // =====================================================

                if context.hasChanges {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "✅ Prepared pirateIslands record: \(docSnapshot.documentID)",
                            level: .success,
                            collection: "pirateIslands"
                        )
                    }
                }
                else {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "ℹ️ No changes detected for PirateIsland \(docSnapshot.documentID)",
                            level: .info,
                            collection: "pirateIslands"
                        )
                    }
                }

            }
            catch {

                context.rollback()

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

        let data = docSnapshot.data() ?? [:]
        guard !data.isEmpty else { return }

        let documentID = docSnapshot.documentID

        let reviewUUID =
            UUID(uuidString: documentID)
            ?? UUID.fromStringID(documentID)


        // ✅ FIX 1: Read cache BEFORE context.perform

        let cachedIslandID: NSManagedObjectID? =
        await MainActor.run {

            guard let islandID =
                data["islandID"] as? String
            else { return nil }

            return FirestoreSyncManager.shared
                .pirateIslandCache[islandID]
        }

        await context.perform {

            do {

                let fetchRequest =
                    Review.fetchRequest() as! NSFetchRequest<Review>

                fetchRequest.predicate =
                    NSPredicate(
                        format: "reviewID == %@",
                        reviewUUID as CVarArg
                    )

                fetchRequest.fetchLimit = 1


                let review =
                    try context.fetch(fetchRequest).first
                    ?? Review(context: context)


                if review.objectID.isTemporaryID {

                    try? context.obtainPermanentIDs(for: [review])
                }


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



                // RELATIONSHIP

                if let islandIDString =
                    data["islandID"] as? String {

                    // CACHE FIRST

                    if let cachedIslandID,
                       let cachedIsland =
                            try? context.existingObject(
                                with: cachedIslandID
                            ) as? PirateIsland {

                        review.island = cachedIsland
                    }

                    // FALLBACK FETCH

                    else {

                        let islandFetch: NSFetchRequest<PirateIsland> =
                            PirateIsland.fetchRequest()

                        islandFetch.predicate =
                            NSPredicate(
                                format: "islandID == %@",
                                islandIDString
                            )

                        islandFetch.fetchLimit = 1


                        if let fetched =
                            try context.fetch(islandFetch).first {

                            review.island = fetched


                            if fetched.objectID.isTemporaryID {

                                try? context.obtainPermanentIDs(
                                    for: [fetched]
                                )
                            }


                            let permanentID =
                                fetched.objectID


                            // ✅ FIX 2: Use Task, NOT await MainActor.run

                            Task { @MainActor in

                                FirestoreSyncManager.shared
                                    .pirateIslandCache[islandIDString] =
                                    permanentID
                            }
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
                }



                if context.hasChanges {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "✅ Prepared Review \(documentID)",
                            level: .success,
                            collection: "reviews"
                        )
                    }
                }

            }
            catch {

                context.rollback()

                Task { @MainActor in

                    FirestoreSyncManager.log(
                        "❌ Failed preparing Review \(documentID)",
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

        let docID = docSnapshot.documentID


        // =====================================================
        // STEP 0: Resolve AppDayOfWeek reference FIRST
        // =====================================================

        guard let appDayRef =
            docSnapshot.get("appDayOfWeek") as? DocumentReference
        else {

            await MainActor.run {

                FirestoreSyncManager.log(
                    "❌ Aborting MatTime — missing appDayOfWeek reference for \(docID)",
                    level: .error,
                    collection: "MatTime"
                )
            }

            return
        }

        let appDayID = appDayRef.documentID


        // =====================================================
        // STEP 1: Read cache safely
        // =====================================================

        let cachedObjectID: NSManagedObjectID? =
            await MainActor.run {

                FirestoreSyncManager.shared
                    .appDayCache[appDayID]
            }


        // =====================================================
        // STEP 2: Core Data work
        // =====================================================

        await context.perform {

            do {

                // =====================================================
                // Resolve UUID safely
                // =====================================================

                let uuid =
                    UUID(uuidString: docID)
                    ?? UUID.fromStringID(docID)


                // =====================================================
                // Fetch or create
                // =====================================================

                let fetchRequest: NSFetchRequest<MatTime> =
                    MatTime.fetchRequest()

                fetchRequest.predicate =
                    NSPredicate(
                        format: "id == %@",
                        uuid as CVarArg
                    )

                fetchRequest.fetchLimit = 1


                let matTime =
                    try context.fetch(fetchRequest).first
                    ?? MatTime(context: context)


                // =====================================================
                // CRITICAL FIX #1
                // Persist ID
                // =====================================================

                matTime.id = uuid


                // =====================================================
                // ⭐ CRITICAL FIX #2
                // Persist foreign key
                // THIS enables relationship self-repair
                // =====================================================

                matTime.appDayOfWeekID = appDayID


                // =====================================================
                // Permanent Object ID
                // =====================================================

                if matTime.objectID.isTemporaryID {

                    try? context.obtainPermanentIDs(
                        for: [matTime]
                    )
                }


                // =====================================================
                // Map fields
                // =====================================================

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


                // =====================================================
                // RELATIONSHIP RESOLUTION
                // =====================================================

                if let cachedObjectID,
                   let cachedAppDay =
                    try? context.existingObject(
                        with: cachedObjectID
                    ) as? AppDayOfWeek {

                    matTime.appDayOfWeek = cachedAppDay
                }

                else {

                    let adoFetch: NSFetchRequest<AppDayOfWeek> =
                        AppDayOfWeek.fetchRequest()

                    adoFetch.predicate =
                        NSPredicate(
                            format: "appDayOfWeekID == %@",
                            appDayID
                        )

                    adoFetch.fetchLimit = 1


                    if let fetched =
                        try context.fetch(adoFetch).first {

                        matTime.appDayOfWeek = fetched


                        // =====================================================
                        // Repair cache
                        // =====================================================

                        if fetched.objectID.isTemporaryID {

                            try? context.obtainPermanentIDs(
                                for: [fetched]
                            )
                        }

                        let permanentID =
                            fetched.objectID


                        Task { @MainActor in

                            FirestoreSyncManager.shared
                                .appDayCache[appDayID] =
                                permanentID
                        }
                    }

                    else {

                        FirestoreSyncManager.log(
                            "⚠️ AppDayOfWeek missing — relationship will auto-repair later",
                            level: .warning,
                            collection: "MatTime"
                        )
                    }
                }


                // =====================================================
                // Final log
                // =====================================================

                if context.hasChanges {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "✅ Prepared MatTime \(docID)",
                            level: .success,
                            collection: "MatTime"
                        )
                    }
                }

            }

            catch {

                context.rollback()

                Task { @MainActor in

                    FirestoreSyncManager.log(
                        "❌ Failed preparing MatTime \(docID): \(error)",
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

        let docID = docSnapshot.documentID


        // =====================================================
        // UNIVERSAL PirateIsland decoder
        // Supports:
        // DocumentReference
        // Map
        // String
        // =====================================================

        let pirateIslandID: String? = {

            if let ref =
                docSnapshot.get("pIsland") as? DocumentReference {

                return ref.documentID
            }

            if let map =
                docSnapshot.get("pIsland") as? [String: Any] {

                return map["islandID"] as? String
            }

            if let string =
                docSnapshot.get("pIsland") as? String {

                return string
            }

            return nil

        }()



        // =====================================================
        // Read cache safely
        // =====================================================

        let cachedIslandObjectID: NSManagedObjectID? =
        await MainActor.run {

            guard let id = pirateIslandID else { return nil }

            return FirestoreSyncManager.shared
                .pirateIslandCache[id]
        }



        // =====================================================
        // Core Data work
        // =====================================================

        await context.perform {

            do {

                // =====================================================
                // FETCH OR CREATE
                // =====================================================

                let fetchRequest: NSFetchRequest<AppDayOfWeek> =
                    AppDayOfWeek.fetchRequest()

                let uuidVersion =
                    UUID.fromStringID(docID).uuidString

                fetchRequest.predicate =
                    NSPredicate(
                        format: "appDayOfWeekID == %@ OR appDayOfWeekID == %@",
                        docID,
                        uuidVersion
                    )

                fetchRequest.fetchLimit = 1


                let ado =
                    try context.fetch(fetchRequest).first
                    ?? {

                        let new =
                            AppDayOfWeek(context: context)

                        new.appDayOfWeekID = docID

                        return new
                    }()



                // =====================================================
                // ⭐ CRITICAL FIX — STORE FOREIGN KEY
                // =====================================================

                ado.pirateIslandID = pirateIslandID



                // =====================================================
                // Permanent Object ID
                // =====================================================

                var permanentObjectID: NSManagedObjectID?

                do {

                    if ado.objectID.isTemporaryID {

                        try context.obtainPermanentIDs(for: [ado])
                    }

                    permanentObjectID = ado.objectID

                }
                catch {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "❌ Failed permanent ID",
                            level: .error,
                            collection: "AppDayOfWeek"
                        )
                    }
                }



                // =====================================================
                // Cache AppDay
                // =====================================================

                if let permanentObjectID {

                    Task { @MainActor in

                        FirestoreSyncManager.shared
                            .appDayCache[docID] =
                            permanentObjectID
                    }
                }



                // =====================================================
                // Required field
                // =====================================================

                guard let day =
                    docSnapshot.get("day") as? String,
                    !day.isEmpty
                else {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "❌ Invalid AppDayOfWeek",
                            level: .error,
                            collection: "AppDayOfWeek"
                        )
                    }

                    return
                }

                ado.day = day

                ado.name =
                    docSnapshot.get("name") as? String ?? ""



                // =====================================================
                // RELATIONSHIP FIX
                // =====================================================

                if let cachedIslandObjectID,
                   let cachedIsland =
                        try? context.existingObject(
                            with: cachedIslandObjectID
                        ) as? PirateIsland {

                    ado.pIsland = cachedIsland
                }
                else if let pirateIslandID {

                    let islandFetch: NSFetchRequest<PirateIsland> =
                        PirateIsland.fetchRequest()

                    islandFetch.predicate =
                        NSPredicate(
                            format: "islandID == %@",
                            pirateIslandID
                        )

                    islandFetch.fetchLimit = 1


                    if let island =
                        try context.fetch(islandFetch).first {

                        ado.pIsland = island


                        // Cache permanent ID

                        if island.objectID.isTemporaryID {

                            try? context.obtainPermanentIDs(
                                for: [island]
                            )
                        }

                        let permanentID =
                            island.objectID


                        Task { @MainActor in

                            FirestoreSyncManager.shared
                                .pirateIslandCache[pirateIslandID] =
                                permanentID
                        }
                    }
                    else {

                        Task { @MainActor in

                            FirestoreSyncManager.log(
                                "❌ PirateIsland not found for AppDayOfWeek \(docID)",
                                level: .error,
                                collection: "AppDayOfWeek"
                            )
                        }
                    }
                }



                // =====================================================
                // Final log
                // =====================================================

                if context.hasChanges {

                    Task { @MainActor in

                        FirestoreSyncManager.log(
                            "✅ Prepared AppDayOfWeek \(docID)",
                            level: .success,
                            collection: "AppDayOfWeek"
                        )
                    }
                }

            }
            catch {

                context.rollback()

                Task { @MainActor in

                    FirestoreSyncManager.log(
                        "❌ Failed AppDayOfWeek \(docID): \(error)",
                        level: .error,
                        collection: "AppDayOfWeek"
                    )
                }
            }
        }
    }
    
    private func repairRelationshipsAndCaches(
        context: NSManagedObjectContext
    ) async throws {

        // =====================================================
        // STEP 1: Rebuild PirateIsland cache
        // =====================================================

        let islands: [(String, NSManagedObjectID)] =
        try await context.perform {

            let request: NSFetchRequest<PirateIsland> =
                PirateIsland.fetchRequest()

            return try context.fetch(request).compactMap {

                guard let id = $0.islandID else { return nil }

                if $0.objectID.isTemporaryID {
                    try? context.obtainPermanentIDs(for: [$0])
                }

                return (id, $0.objectID)
            }
        }

        await MainActor.run {

            for (id, objectID) in islands {

                pirateIslandCache[id] = objectID
            }
        }



        // =====================================================
        // STEP 2: Rebuild AppDayOfWeek cache
        // =====================================================

        let days: [(String, NSManagedObjectID)] =
        try await context.perform {

            let request: NSFetchRequest<AppDayOfWeek> =
                AppDayOfWeek.fetchRequest()

            return try context.fetch(request).compactMap {

                guard let id = $0.appDayOfWeekID else { return nil }

                if $0.objectID.isTemporaryID {
                    try? context.obtainPermanentIDs(for: [$0])
                }

                return (id, $0.objectID)
            }
        }

        await MainActor.run {

            for (id, objectID) in days {

                appDayCache[id] = objectID
            }
        }



        // =====================================================
        // STEP 3: Repair AppDayOfWeek → PirateIsland
        // USING FOREIGN KEY
        // =====================================================

        try await context.perform {

            let request: NSFetchRequest<AppDayOfWeek> =
                AppDayOfWeek.fetchRequest()

            let days = try context.fetch(request)

            for day in days {

                if day.pIsland != nil { continue }

                guard let islandID =
                    day.pirateIslandID
                else { continue }


                let islandFetch: NSFetchRequest<PirateIsland> =
                    PirateIsland.fetchRequest()

                islandFetch.predicate =
                    NSPredicate(
                        format: "islandID == %@",
                        islandID
                    )

                islandFetch.fetchLimit = 1


                if let island =
                    try context.fetch(islandFetch).first {

                    day.pIsland = island

                    FirestoreSyncManager.log(
                        "🔧 Repaired AppDayOfWeek → PirateIsland",
                        level: .success,
                        collection: "Repair"
                    )
                }
            }
        }



        // =====================================================
        // STEP 4: Repair MatTime → AppDayOfWeek
        // USING FOREIGN KEY
        // =====================================================

        try await context.perform {

            let request: NSFetchRequest<MatTime> =
                MatTime.fetchRequest()

            let mats = try context.fetch(request)

            for mat in mats {

                if mat.appDayOfWeek != nil { continue }

                guard let appDayID =
                    mat.appDayOfWeekID
                else { continue }


                let fetch: NSFetchRequest<AppDayOfWeek> =
                    AppDayOfWeek.fetchRequest()

                fetch.predicate =
                    NSPredicate(
                        format: "appDayOfWeekID == %@",
                        appDayID
                    )

                fetch.fetchLimit = 1


                if let ado =
                    try context.fetch(fetch).first {

                    mat.appDayOfWeek = ado

                    FirestoreSyncManager.log(
                        "🔧 Repaired MatTime → AppDayOfWeek",
                        level: .success,
                        collection: "Repair"
                    )
                }
            }
        }



        // =====================================================
        // STEP 5: Save repairs
        // =====================================================

        try await context.perform {

            if context.hasChanges {

                try context.save()

                FirestoreSyncManager.log(
                    "💾 Relationship repair saved",
                    level: .success,
                    collection: "Repair"
                )
            }
        }
    }
    
    @MainActor
    func inferPirateIslandID(
        from day: AppDayOfWeek
    ) -> String? {

        // your Firestore structure stores islandID inside name

        if let name = day.name {

            // example:
            // "Dojo by Leo Vieira - Jiu Jitsu - thursday"

            let islands =
                pirateIslandCache.keys

            return islands.first {

                name.contains($0)
            }
        }

        return nil
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

        let listener = db.collection(collectionName)
            .addSnapshotListener { [weak self] snapshot, error in

                guard self != nil else { return }

                // -----------------------------------------
                // Error handling
                // -----------------------------------------
                if let error {

                    Task { @MainActor in

                        Self.log(
                            "❌ Listener error: \(error.localizedDescription)",
                            level: .error,
                            collection: collectionName
                        )
                    }

                    return
                }

                guard let snapshot else { return }


                // -----------------------------------------
                // Ignore local writes
                // -----------------------------------------
                if snapshot.metadata.hasPendingWrites {

                    Task { @MainActor in

                        Self.log(
                            "⏭️ Skipping local pending writes (snapshot)",
                            level: .info,
                            collection: collectionName
                        )
                    }

                    return
                }


                // -----------------------------------------
                // ✅ Correct processing
                // -----------------------------------------
                Task(priority: .utility) {

                    // ✅ Create ONE context per snapshot
                    let backgroundContext = await MainActor.run {

                        PersistenceController.shared
                            .newFirestoreContext()
                    }


                    // ✅ Process ALL changes first
                    for change in snapshot.documentChanges {

                        if change.document.metadata.hasPendingWrites {

                            await MainActor.run {

                                Self.log(
                                    "⏭️ Skipping local pending writes (document)",
                                    level: .info,
                                    collection: collectionName
                                )
                            }

                            continue
                        }

                        await handler(
                            change,
                            backgroundContext
                        )
                    }



                    // -----------------------------------------
                    // ✅ Save ONCE
                    // -----------------------------------------
                    await backgroundContext.perform {

                        guard backgroundContext.hasChanges else { return }

                        backgroundContext.processPendingChanges()

                        do {

                            try backgroundContext.save()

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

                            return
                        }
                    }



                    // -----------------------------------------
                    // ✅ Repair cache AFTER save
                    // -----------------------------------------
                    do {

                        try await FirestoreSyncManager.shared
                            .repairRelationshipsAndCaches(
                                context: backgroundContext
                            )

                    }
                    catch {

                        await MainActor.run {

                            Self.log(
                                "❌ Cache repair failed after batch",
                                level: .error,
                                collection: collectionName
                            )
                        }
                    }



                    // -----------------------------------------
                    // ✅ Reset LAST
                    // -----------------------------------------
                    await backgroundContext.perform {

                        backgroundContext.refreshAllObjects()

                        backgroundContext.reset()
                    }



                    // -----------------------------------------
                    // Log success
                    // -----------------------------------------
                    await MainActor.run {

                        Self.log(
                            "✅ Listener batch saved successfully",
                            level: .success,
                            collection: collectionName
                        )
                    }

                }
            }


        // Store listener
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

        // =====================================================
        // ADDED / MODIFIED
        // =====================================================

        case .added, .modified:

            // ✅ Only mutate Core Data
            // ❌ DO NOT repair cache here
            await syncPirateIslandStatic(
                docSnapshot: change.document,
                context: context
            )



        // =====================================================
        // REMOVED
        // =====================================================

        case .removed:

            // ✅ Only delete
            // ❌ DO NOT repair cache here
            await context.perform {

                deleteEntity(
                    ofType: PirateIsland.self,
                    idString: change.document.documentID,
                    keyPath: \.islandID,
                    context: context
                )
            }
        }
    }
    
    static func handleReviewChange(
        _ change: DocumentChange,
        _ context: NSManagedObjectContext
    ) async {

        switch change.type {

        // =====================================================
        // ADDED / MODIFIED
        // =====================================================

        case .added, .modified:

            // ✅ Only mutate Core Data
            // ❌ DO NOT repair cache here
            await syncReviewStatic(
                docSnapshot: change.document,
                context: context
            )



        // =====================================================
        // REMOVED
        // =====================================================

        case .removed:

            // ✅ Only delete
            // ❌ DO NOT repair cache here
            await context.perform {

                deleteEntity(
                    ofType: Review.self,
                    idString: change.document.documentID,
                    keyPath: \.reviewID,
                    context: context
                )
            }
        }
    }
    
    
    static func handleAppDayOfWeekChange(
        _ change: DocumentChange,
        _ context: NSManagedObjectContext
    ) async {

        switch change.type {

        // =====================================================
        // ADDED / MODIFIED
        // =====================================================

        case .added, .modified:

            // ✅ Only mutate Core Data
            // ❌ DO NOT repair cache here
            await syncAppDayOfWeekStatic(
                docSnapshot: change.document,
                context: context
            )



        // =====================================================
        // REMOVED
        // =====================================================

        case .removed:

            // ✅ Only delete
            // ❌ DO NOT repair cache here
            await context.perform {

                deleteEntity(
                    ofType: AppDayOfWeek.self,
                    idString: change.document.documentID,
                    keyPath: \.appDayOfWeekID,
                    context: context
                )
            }
        }
    }


    static func handleMatTimeChange(
        _ change: DocumentChange,
        _ context: NSManagedObjectContext
    ) async {

        switch change.type {

        // =====================================================
        // ADDED / MODIFIED
        // =====================================================

        case .added, .modified:

            // ✅ Only mutate Core Data
            // ❌ DO NOT repair cache here
            await syncMatTimeStatic(
                docSnapshot: change.document,
                context: context
            )



        // =====================================================
        // REMOVED
        // =====================================================

        case .removed:

            // ✅ Only delete
            // ❌ DO NOT repair cache here
            await context.perform {

                deleteEntity(
                    ofType: MatTime.self,
                    idString: change.document.documentID,
                    keyPath: \.id,
                    context: context
                )
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
