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
import CryptoKit


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
    
    nonisolated static func log(
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
        defer { isSyncInProgress = false }

        let didComplete = await FirestoreSyncManager.shared.syncInitialFirestoreData()

        if didComplete {
            hasPerformedInitialSync = true

            await MainActor.run {
                FirestoreSyncManager.shared.startFirestoreListeners()
            }
        }
    }
}


@MainActor
class FirestoreSyncManager: ObservableObject {
    static let shared = FirestoreSyncManager()

    @Published var isSyncing = false
    @Published var syncStatusMessage = "Updating data… you can keep using the app"
    private var initialSyncCompleted = false

    private var pirateIslandCache: [String: NSManagedObjectID] = [:]
    private var appDayCache: [String: NSManagedObjectID] = [:]
    private static var listenerRegistrations: [ListenerRegistration] = []
    
    func syncInitialFirestoreData() async -> Bool {
        pirateIslandCache.removeAll()
        appDayCache.removeAll()
        
        FirestoreSyncManager.log(
            "🚀 Starting initial Firestore sync",
            level: .sync
        )

        isSyncing = true
        syncStatusMessage = "Updating data… you can keep using the app"

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
            // SAFE UI LOGGING + FINAL SUCCESS TOAST
            // ---------------------------------------------------------

            FirestoreSyncManager.log(
                "🧩 Core Data graph fully merged and stable",
                level: .finished
            )

            initialSyncCompleted = true
            isSyncing = false

            ToastThrottler.shared.postToast(
                for: "Sync",
                action: "Data is up to date",
                type: .success,
                isPersistent: false
            )

            FirestoreSyncManager.log(
                "✅ Initial Firestore sync complete",
                level: .finished
            )

            return true

        }
        catch {

            FirestoreSyncManager.log(
                "❌ Initial Firestore sync failed: \(error.localizedDescription)",
                level: .error
            )

            initialSyncCompleted = false
            isSyncing = false

            ToastThrottler.shared.postToast(
                for: "Sync",
                action: "Sync failed",
                type: .error,
                isPersistent: false
            )

            return false
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

        try await downloadFirestoreDocumentsToLocal(
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
                let querySnapshot = try await Firestore.firestore()
                    .collection(collectionName)
                    .getDocuments()

                if collectionName == "MatTime" || collectionName == "AppDayOfWeek" {
                    if querySnapshot.documents.isEmpty {
                        FirestoreSyncManager.log(
                            "No documents found in collection \(collectionName).",
                            level: .warning,
                            collection: collectionName
                        )
                    } else {
                        FirestoreSyncManager.log(
                            "Collection \(collectionName) has \(querySnapshot.documents.count) documents.",
                            level: .info,
                            collection: collectionName
                        )
                        FirestoreSyncManager.log(
                            "Document IDs: \(querySnapshot.documents.map { $0.documentID })",
                            level: .info,
                            collection: collectionName
                        )
                    }
                }

                try await self.checkLocalRecordsAndCreateFirestoreRecordsIfNecessary(
                    collectionName: collectionName,
                    querySnapshot: querySnapshot
                )

            } catch {
                FirestoreSyncManager.log(
                    "Error checking Firestore records for \(collectionName): \(error)",
                    level: .error,
                    collection: collectionName
                )
                throw error
            }
        }
    }
    
    private func downloadFirestoreDocumentsToLocal(
        collectionName: String,
        documents: [QueryDocumentSnapshot]
    ) async throws {

        let context = await MainActor.run {
            PersistenceController.shared.newFirestoreContext()
        }

        do {

            // STEP 1: Sync all objects
            for doc in documents {
                switch collectionName {

                case "pirateIslands":
                    await Self.syncPirateIslandStatic(
                        docSnapshot: doc,
                        context: context
                    )

                case "reviews":
                    await Self.syncReviewStatic(
                        docSnapshot: doc,
                        context: context
                    )

                case "AppDayOfWeek":
                    await Self.syncAppDayOfWeekStatic(
                        docSnapshot: doc,
                        context: context
                    )

                case "MatTime":
                    await Self.syncMatTimeStatic(
                        docSnapshot: doc,
                        context: context
                    )

                default:
                    FirestoreSyncManager.log(
                        "⚠️ Unknown collection \(collectionName) during download",
                        level: .warning,
                        collection: collectionName
                    )
                }
            }

            // STEP 2: Save once
            try await context.perform {
                guard context.hasChanges else { return }

                context.processPendingChanges()
                try context.save()
            }

            // STEP 3: Reset only
            await context.perform {
                context.refreshAllObjects()
                context.reset()
            }

            FirestoreSyncManager.log(
                "✅ Transaction complete",
                level: .success,
                collection: collectionName
            )

        } catch {

            await context.perform {
                context.rollback()
            }

            FirestoreSyncManager.log(
                "❌ Transaction failed: \(error)",
                level: .error,
                collection: collectionName
            )

            throw error
        }
    }
                
    private func checkLocalRecordsAndCreateFirestoreRecordsIfNecessary(
        collectionName: String,
        querySnapshot: QuerySnapshot?
    ) async throws {

        let syncID = String(UUID().uuidString.prefix(8))

        FirestoreSyncManager.log(
            "Starting sync for \(collectionName)",
            level: .upload,
            collection: collectionName,
            syncID: syncID
        )

        FirestoreSyncManager.log(
            "Initiating record check for collection: \(collectionName)",
            level: .upload,
            collection: collectionName,
            syncID: syncID
        )

        FirestoreSyncManager.log(
            """
            Checking network status before sync:
            - isConnected: \(NetworkMonitor.shared.isConnected)
            - currentPath: \(String(describing: NetworkMonitor.shared.currentPath))
            - currentStatus: \(String(describing: NetworkMonitor.shared.currentPath?.status))
            - hasShownNoInternetToast: \(Mirror(reflecting: NetworkMonitor.shared)
                .children.first { $0.label == "hasShownNoInternetToast" }?.value ?? "N/A")
            """,
            level: .info,
            collection: collectionName,
            syncID: syncID
        )

        guard NetworkMonitor.shared.isConnected else {
            FirestoreSyncManager.log(
                "Network offline. Skipping \(collectionName) sync.",
                level: .warning,
                collection: collectionName,
                syncID: syncID
            )

            await MainActor.run {
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: "skipped",
                    type: .info,
                    isPersistent: true
                )
            }

            throw NSError(
                domain: "FirestoreSyncManager",
                code: 1002,
                userInfo: [
                    NSLocalizedDescriptionKey: "Network offline while syncing \(collectionName)"
                ]
            )
        }

        guard let querySnapshot else {
            FirestoreSyncManager.log(
                "Query snapshot is nil for \(collectionName). Cannot proceed.",
                level: .error,
                collection: collectionName,
                syncID: syncID
            )

            throw NSError(
                domain: "FirestoreSyncManager",
                code: 1003,
                userInfo: [
                    NSLocalizedDescriptionKey: "Query snapshot was nil for \(collectionName)"
                ]
            )
        }

        FirestoreSyncManager.log(
            "Query snapshot received for \(collectionName)",
            level: .success,
            collection: collectionName,
            syncID: syncID
        )

        let firestoreRecords = querySnapshot.documents.map(\.documentID)

        FirestoreSyncManager.log(
            "Firestore records (\(firestoreRecords.count)): \(firestoreRecords.prefix(5))\(firestoreRecords.count > 5 ? "... (\(firestoreRecords.count - 5) more)" : "")",
            level: .download,
            collection: collectionName,
            syncID: syncID
        )

        do {
            let localRecords =
                try await PersistenceController.shared
                    .fetchLocalRecords(forCollection: collectionName) ?? []

            FirestoreSyncManager.log(
                "Local records (\(localRecords.count)): \(localRecords.prefix(5))\(localRecords.count > 5 ? "... (\(localRecords.count - 5) more)" : "")",
                level: .info,
                collection: collectionName,
                syncID: syncID
            )

            try await syncRecords(
                localRecords: localRecords,
                firestoreRecords: firestoreRecords,
                collectionName: collectionName
            )

            if localRecords.isEmpty {
                await MainActor.run {
                    ToastThrottler.shared.postToast(
                        for: collectionName,
                        action: "initialized from cloud",
                        type: .info,
                        isPersistent: false
                    )
                }
            }

        } catch {
            FirestoreSyncManager.log(
                "Critical sync error for \(collectionName): \(error.localizedDescription)",
                level: .error,
                collection: collectionName,
                syncID: syncID
            )

            await MainActor.run {
                ToastThrottler.shared.postToast(
                    for: collectionName,
                    action: "failed to fetch",
                    type: .error,
                    isPersistent: true
                )
            }

            throw error
        }

        FirestoreSyncManager.log(
            "Finished checking local records for \(collectionName)",
            level: .finished,
            collection: collectionName,
            syncID: syncID
        )
    }

    
    // MARK: - Main download & sync coordinator
    private func syncRecords(
        localRecords: [String],
        firestoreRecords: [String],
        collectionName: String
    ) async throws {

        func normalize(_ id: String) -> String {
            id
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "-", with: "")
                .lowercased()
        }

        // ------------------------------------------------------------
        // Debug raw values
        // ------------------------------------------------------------

        Self.log(
            "🧪 LOCAL RAW: \(localRecords)",
            level: .info,
            collection: collectionName
        )

        Self.log(
            "🧪 FIRESTORE RAW: \(firestoreRecords)",
            level: .info,
            collection: collectionName
        )

        // ------------------------------------------------------------
        // Normalize for comparison
        // ------------------------------------------------------------

        let normalizedFirestoreRecords = firestoreRecords.map(normalize)
        let normalizedLocalRecords = localRecords.map(normalize)

        // ------------------------------------------------------------
        // Identify local records missing in Firestore
        // ------------------------------------------------------------

        let localRecordsNotInFirestore = localRecords.filter {
            !normalizedFirestoreRecords.contains(normalize($0))
        }

        // ------------------------------------------------------------
        // Identify Firestore records missing locally
        // ------------------------------------------------------------

        let firestoreRecordsNotInLocal = firestoreRecords.filter {
            !normalizedLocalRecords.contains(normalize($0))
        }

        // ------------------------------------------------------------
        // Sync summary
        // ------------------------------------------------------------

        Self.log(
            """
            🔄 Starting sync for \(collectionName):
            • 🗑️ \(localRecordsNotInFirestore.count) local-only records
            • 📥 \(firestoreRecordsNotInLocal.count) Firestore → Core Data
            """,
            level: .sync,
            collection: collectionName
        )

        // ------------------------------------------------------------
        // Delete orphaned local
        // ------------------------------------------------------------

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
        } else {
            Self.log(
                "✅ No orphaned local records",
                level: .success,
                collection: collectionName
            )
        }

        // ------------------------------------------------------------
        // Download missing Firestore records
        // ------------------------------------------------------------

        if !firestoreRecordsNotInLocal.isEmpty {
            Self.log(
                "⬇️ Downloading \(firestoreRecordsNotInLocal.count) records from Firestore",
                level: .download,
                collection: collectionName
            )

            try await downloadFirestoreRecordsToLocal(
                collectionName: collectionName,
                records: firestoreRecordsNotInLocal
            )
        } else {
            Self.log(
                "✅ No missing Firestore records",
                level: .success,
                collection: collectionName
            )
        }

        // ------------------------------------------------------------
        // Completion summary
        // ------------------------------------------------------------

        Self.log(
            """
            🏁 Finished sync for \(collectionName)
            • Deleted: \(localRecordsNotInFirestore.count)
            • Downloaded: \(firestoreRecordsNotInLocal.count)
            """,
            level: .finished,
            collection: collectionName
        )

        // ------------------------------------------------------------
        // Wait for Core Data merge
        // ------------------------------------------------------------

        await PersistenceController.shared.waitForBackgroundSaves()

        // ------------------------------------------------------------
        // Final integrity check
        // ------------------------------------------------------------

        let refreshedLocalRecords =
            (try? await PersistenceController.shared
                .fetchLocalRecords(forCollection: collectionName)) ?? []

        Self.log(
            "🧪 DEBUG LOCAL IDS AFTER SYNC: \(refreshedLocalRecords)",
            level: .info,
            collection: collectionName
        )

        Self.log(
            "🧪 DEBUG FIRESTORE IDS: \(firestoreRecords)",
            level: .info,
            collection: collectionName
        )

        let refreshedLocalNormalized = refreshedLocalRecords.map(normalize)
        let firestoreNormalized = firestoreRecords.map(normalize)

        let missingLocalFinal = firestoreRecords.filter {
            !refreshedLocalNormalized.contains(normalize($0))
        }

        let missingRemoteFinal = refreshedLocalRecords.filter {
            !firestoreNormalized.contains(normalize($0))
        }

        Self.log(
            "Integrity check → local=\(refreshedLocalRecords.count), firestore=\(firestoreRecords.count)",
            level: .sync,
            collection: collectionName
        )

        if !missingLocalFinal.isEmpty || !missingRemoteFinal.isEmpty {
            Self.log(
                """
                ⚠️ Integrity mismatch after sync:
                • Missing locally: \(missingLocalFinal.count)
                • Missing in cloud: \(missingRemoteFinal.count)
                """,
                level: .error,
                collection: collectionName
            )

            throw NSError(
                domain: "FirestoreSyncManager",
                code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Integrity check failed for \(collectionName). Missing locally: \(missingLocalFinal.count), missing in cloud: \(missingRemoteFinal.count)"
                ]
            )
        }

        Self.log(
            "✅ Integrity check passed",
            level: .success,
            collection: collectionName
        )
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
                    Self.deleteEntityByStringID(
                        ofType: PirateIsland.self,
                        idString: record,
                        fieldName: "islandID",
                        context: context
                    )

                case "reviews":
                    Self.deleteEntityByUUID(
                        ofType: Review.self,
                        idString: record,
                        fieldName: "reviewID",
                        context: context
                    )

                case "MatTime":
                    Self.deleteEntityByUUID(
                        ofType: MatTime.self,
                        idString: record,
                        fieldName: "id",
                        context: context
                    )

                case "AppDayOfWeek":
                    Self.deleteEntityByStringID(
                        ofType: AppDayOfWeek.self,
                        idString: record,
                        fieldName: "appDayOfWeekID",
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

                context.refreshAllObjects()
                context.reset()

                if let parent = context.parent {
                    parent.performAndWait {
                        parent.refreshAllObjects()
                    }
                }

                FirestoreSyncManager.log(
                    "💾 Deleted \(records.count) local orphaned records",
                    level: .success,
                    collection: collectionName
                )
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
    ) async throws {

        guard !records.isEmpty else { return }

        let context = await MainActor.run {
            PersistenceController.shared.newFirestoreContext()
        }

        let collectionRef = Firestore.firestore().collection(collectionName)

        var downloadedCount = 0
        var errorCount = 0

        do {
            for chunk in records.chunked(into: 10) {
                let snapshot = try await collectionRef
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                for docSnapshot in snapshot.documents {
                    switch collectionName {

                    case "pirateIslands":
                        await Self.syncPirateIslandStatic(
                            docSnapshot: docSnapshot,
                            context: context
                        )
                        downloadedCount += 1

                    case "reviews":
                        await Self.syncReviewStatic(
                            docSnapshot: docSnapshot,
                            context: context
                        )
                        downloadedCount += 1

                    case "MatTime":
                        await Self.syncMatTimeStatic(
                            docSnapshot: docSnapshot,
                            context: context
                        )
                        downloadedCount += 1

                    case "AppDayOfWeek":
                        await Self.syncAppDayOfWeekStatic(
                            docSnapshot: docSnapshot,
                            context: context
                        )
                        downloadedCount += 1

                    default:
                        errorCount += 1
                        FirestoreSyncManager.log(
                            "⚠️ Unknown collection \(collectionName) during batch download",
                            level: .warning,
                            collection: collectionName
                        )
                    }
                }
            }

            try await context.perform {
                guard context.hasChanges else { return }
                context.processPendingChanges()
                try context.save()
            }

            await context.perform {
                context.refreshAllObjects()
                context.reset()
            }

            FirestoreSyncManager.log(
                "🏁 Batch download complete: \(downloadedCount) success, \(errorCount) errors",
                level: errorCount > 0 ? .warning : .success,
                collection: collectionName
            )

        } catch {
            await context.perform {
                context.rollback()
            }

            FirestoreSyncManager.log(
                "❌ Batch transaction failed: \(error)",
                level: .error,
                collection: collectionName
            )

            throw error
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

                // ✅ Drop-in fee fields

                let dropInRaw: Int16 = {
                    if let value = data["hasDropInFee"] as? Int16 { return value }
                    if let value = data["hasDropInFee"] as? Int { return Int16(value) }
                    return HasDropInFee.notConfirmed.rawValue
                }()

                island.hasDropInFee = dropInRaw
                island.dropInFeeAmount =
                    data["dropInFeeAmount"] as? Double ?? 0
                island.dropInFeeNote =
                    data["dropInFeeNote"] as? String

                // =====================================================
                // CRITICAL FIX — Obtain and cache permanent ID explicitly
                // =====================================================

                var permanentObjectID: NSManagedObjectID?

                do {
                    if island.objectID.isTemporaryID {
                        try context.obtainPermanentIDs(for: [island])
                    }

                    permanentObjectID = island.objectID

                } catch {
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "❌ Failed to obtain permanent PirateIsland ID",
                            level: .error,
                            collection: "pirateIslands"
                        )
                    }
                }

                if let permanentObjectID {
                    Task { @MainActor in
                        FirestoreSyncManager.shared
                            .pirateIslandCache[docSnapshot.documentID] =
                            permanentObjectID
                    }
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
                } else {
                    Task { @MainActor in
                        FirestoreSyncManager.log(
                            "ℹ️ No changes detected for PirateIsland \(docSnapshot.documentID)",
                            level: .info,
                            collection: "pirateIslands"
                        )
                    }
                }

            } catch {

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
        // STEP 0: Resolve AppDayOfWeek reference OR foreign key
        // Supports:
        // - appDayOfWeek as DocumentReference
        // - appDayOfWeekID as String
        // =====================================================

        let appDayID: String

        if let appDayRef =
            docSnapshot.get("appDayOfWeek") as? DocumentReference {

            appDayID = appDayRef.documentID

        } else if let rawID =
                    docSnapshot.get("appDayOfWeekID") as? String,
                  !rawID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

            appDayID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)

        } else {

            await MainActor.run {

                FirestoreSyncManager.log(
                    "❌ Aborting MatTime — missing appDayOfWeek reference/ID for \(docID)",
                    level: .error,
                    collection: "MatTime"
                )
            }

            return
        }
        // =====================================================
        // STEP 1: Read cache safely
        // =====================================================

        let cachedObjectID: NSManagedObjectID? =
            await MainActor.run {

                FirestoreSyncManager.shared
                    .appDayCache[appDayID]
            }

        // =====================================================
        // STEP 2: Normalize values using shared dedupe helper
        // =====================================================

        let uuid =
            UUID(uuidString: docID)
            ?? UUID.fromStringID(docID)

        let timeValue =
            MatTimeDedupe.normalizeTime(
                docSnapshot.get("time") as? String
            )

        let disciplineValue =
            MatTimeDedupe.normalizedDiscipline(
                docSnapshot.get("discipline") as? String
            )

        let styleValue =
            MatTimeDedupe.normalize(
                docSnapshot.get("style") as? String
            )

        let customStyleValue =
            MatTimeDedupe.normalize(
                docSnapshot.get("customStyle") as? String
            )

        let typeValue =
            MatTimeDedupe.normalize(
                docSnapshot.get("type") as? String
            )

        let restrictionsValue =
            docSnapshot.get("restrictions") as? Bool ?? false

        let restrictionDescriptionValue =
            MatTimeDedupe.normalizeRestriction(
                docSnapshot.get("restrictionDescription") as? String
            )

        let goodForBeginnersValue =
            docSnapshot.get("goodForBeginners") as? Bool ?? false

        let kidsValue =
            docSnapshot.get("kids") as? Bool ?? false

        let womensOnlyValue =
            docSnapshot.get("womensOnly") as? Bool ?? false

        // =====================================================
        // STEP 3: Core Data work
        // =====================================================

        await context.perform {

            do {

                // =====================================================
                // A. Try exact ID match first
                // =====================================================

                let idFetch: NSFetchRequest<MatTime> =
                    MatTime.fetchRequest()

                idFetch.predicate =
                    NSPredicate(
                        format: "id == %@",
                        uuid as CVarArg
                    )

                idFetch.fetchLimit = 1

                let existingByID =
                    try context.fetch(idFetch).first

                // =====================================================
                // B. If no exact ID match, use shared dedupe predicate
                // =====================================================

                let matTime: MatTime

                if let existingByID {
                    matTime = existingByID
                } else {

                    let dedupeFetch: NSFetchRequest<MatTime> =
                        MatTime.fetchRequest()

                    dedupeFetch.predicate =
                        MatTimeDedupe.predicate(
                            appDayID: appDayID,
                            time: timeValue,
                            discipline: disciplineValue,
                            style: styleValue,
                            customStyle: customStyleValue,
                            type: typeValue,
                            restrictionDescription: restrictionDescriptionValue,
                            kids: kidsValue,
                            womensOnly: womensOnlyValue,
                            goodForBeginners: goodForBeginnersValue,
                            restrictions: restrictionsValue
                        )

                    dedupeFetch.fetchLimit = 1

                    matTime =
                        try context.fetch(dedupeFetch).first
                        ?? MatTime(context: context)
                }

                // =====================================================
                // STEP 4: Persist identifiers
                // =====================================================

                matTime.id = uuid
                matTime.appDayOfWeekID = appDayID

                if matTime.objectID.isTemporaryID {
                    try? context.obtainPermanentIDs(for: [matTime])
                }

                // =====================================================
                // STEP 5: Map normalized fields
                // =====================================================

                matTime.time = timeValue

                matTime.discipline = disciplineValue

                matTime.style =
                    styleValue.isEmpty ? nil : styleValue

                matTime.customStyle =
                    customStyleValue.isEmpty ? nil : customStyleValue

                matTime.type =
                    typeValue.isEmpty ? nil : typeValue

                matTime.restrictions = restrictionsValue

                matTime.restrictionDescription =
                    restrictionDescriptionValue.isEmpty
                    ? nil
                    : restrictionDescriptionValue

                matTime.goodForBeginners =
                    goodForBeginnersValue

                matTime.kids = kidsValue

                matTime.womensOnly = womensOnlyValue

                matTime.createdTimestamp =
                    (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()
                    ?? matTime.createdTimestamp
                    ?? Date()

                // =====================================================
                // STEP 6: RELATIONSHIP RESOLUTION
                // =====================================================

                if let cachedObjectID,
                   let cachedAppDay =
                        try? context.existingObject(
                            with: cachedObjectID
                        ) as? AppDayOfWeek {

                    matTime.appDayOfWeek = cachedAppDay
                }
                else {

                    FirestoreSyncManager.log(
                        "⚠️ AppDayOfWeek \(appDayID) not yet cached — relationship will repair later",
                        level: .warning,
                        collection: "MatTime"
                    )
                }

                // =====================================================
                // STEP 7: Final log
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
        // - pIsland as DocumentReference
        // - pIsland as map
        // - pIsland as String
        // - pirateIslandID as String
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
                docSnapshot.get("pIsland") as? String,
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return string.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if let rawID =
                docSnapshot.get("pirateIslandID") as? String,
               !rawID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return rawID.trimmingCharacters(in: .whitespacesAndNewlines)
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

                let existing =
                    try context.fetch(fetchRequest).first

                let ado =
                    existing ?? AppDayOfWeek(context: context)

                let isNew =
                    (existing == nil)

                ado.appDayOfWeekID = docID
                ado.pirateIslandID = pirateIslandID

                // =====================================================
                // Required field
                // =====================================================

                guard let day =
                    docSnapshot.get("day") as? String,
                    !day.isEmpty
                else {

                    if isNew {
                        context.delete(ado)
                    }

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
                // Moved AFTER validation so invalid records are not cached
                // =====================================================

                if let permanentObjectID {

                    Task { @MainActor in

                        FirestoreSyncManager.shared
                            .appDayCache[docID] =
                            permanentObjectID
                    }
                }

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

        let rebuiltCaches = try await context.perform {
            () throws -> ([String: NSManagedObjectID], [String: NSManagedObjectID], Int, Int) in

            // =====================================================
            // STEP 1: Rebuild caches from current Core Data state
            // =====================================================

            let islandRequest: NSFetchRequest<PirateIsland> =
                PirateIsland.fetchRequest()

            let dayRequest: NSFetchRequest<AppDayOfWeek> =
                AppDayOfWeek.fetchRequest()

            let islands = try context.fetch(islandRequest)
            let days = try context.fetch(dayRequest)

            var rebuiltPirateIslandCache: [String: NSManagedObjectID] = [:]
            var rebuiltAppDayCache: [String: NSManagedObjectID] = [:]

            for island in islands {
                guard let id = island.islandID else { continue }

                if island.objectID.isTemporaryID {
                    try? context.obtainPermanentIDs(for: [island])
                }

                rebuiltPirateIslandCache[id] = island.objectID
            }

            for day in days {
                guard let id = day.appDayOfWeekID else { continue }

                if day.objectID.isTemporaryID {
                    try? context.obtainPermanentIDs(for: [day])
                }

                rebuiltAppDayCache[id] = day.objectID
            }

            // =====================================================
            // STEP 2: Repair AppDayOfWeek → PirateIsland
            // =====================================================

            var repairedDayToIslandCount = 0

            for day in days {
                if day.pIsland != nil { continue }
                guard let islandID = day.pirateIslandID else { continue }

                let islandFetch: NSFetchRequest<PirateIsland> =
                    PirateIsland.fetchRequest()

                islandFetch.predicate =
                    NSPredicate(format: "islandID == %@", islandID)

                islandFetch.fetchLimit = 1

                if let island = try context.fetch(islandFetch).first {
                    day.pIsland = island
                    repairedDayToIslandCount += 1
                }
            }

            // =====================================================
            // STEP 3: Repair MatTime → AppDayOfWeek
            // =====================================================

            let matRequest: NSFetchRequest<MatTime> =
                MatTime.fetchRequest()

            let mats = try context.fetch(matRequest)

            var repairedMatToDayCount = 0

            for mat in mats {
                if mat.appDayOfWeek != nil { continue }
                guard let appDayID = mat.appDayOfWeekID else { continue }

                let uuidVersion = UUID.fromStringID(appDayID).uuidString

                let dayFetch: NSFetchRequest<AppDayOfWeek> =
                    AppDayOfWeek.fetchRequest()

                dayFetch.predicate =
                    NSPredicate(
                        format: "appDayOfWeekID == %@ OR appDayOfWeekID == %@",
                        appDayID,
                        uuidVersion
                    )

                dayFetch.fetchLimit = 1

                if let ado = try context.fetch(dayFetch).first {
                    mat.appDayOfWeek = ado
                    repairedMatToDayCount += 1
                }
            }

            // =====================================================
            // STEP 4: Save repairs if needed
            // =====================================================

            if context.hasChanges {
                context.processPendingChanges()
                try context.save()
            }

            return (
                rebuiltPirateIslandCache,
                rebuiltAppDayCache,
                repairedDayToIslandCount,
                repairedMatToDayCount
            )
        }

        let (
            rebuiltPirateIslandCache,
            rebuiltAppDayCache,
            repairedDayToIslandCount,
            repairedMatToDayCount
        ) = rebuiltCaches

        self.pirateIslandCache = rebuiltPirateIslandCache
        self.appDayCache = rebuiltAppDayCache

        FirestoreSyncManager.log(
            """
            ✅ Relationship repair finished
            • Repaired AppDayOfWeek → PirateIsland: \(repairedDayToIslandCount)
            • Repaired MatTime → AppDayOfWeek: \(repairedMatToDayCount)
            • PirateIsland cache size: \(rebuiltPirateIslandCache.count)
            • AppDayOfWeek cache size: \(rebuiltAppDayCache.count)
            """,
            level: .success,
            collection: "Repair"
        )
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
                // Process snapshot
                // -----------------------------------------
                Task(priority: .utility) {
                    
                    let backgroundContext = await MainActor.run {
                        PersistenceController.shared.newFirestoreContext()
                    }
                    
                    do {
                        // -----------------------------------------
                        // Process all document changes
                        // -----------------------------------------
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
                            
                            await handler(change, backgroundContext)
                        }
                        
                        // -----------------------------------------
                        // Save ONCE after processing changes
                        // -----------------------------------------
                        try await backgroundContext.perform {
                            guard backgroundContext.hasChanges else { return }
                            backgroundContext.processPendingChanges()
                            try backgroundContext.save()
                        }
                        
                        // -----------------------------------------
                        // Repair relationships using a fresh context
                        // -----------------------------------------
                        let repairContext = await MainActor.run {
                            PersistenceController.shared.newFirestoreContext()
                        }
                        
                        do {
                            try await FirestoreSyncManager.shared
                                .repairRelationshipsAndCaches(
                                    context: repairContext
                                )
                        } catch {
                            await repairContext.perform {
                                repairContext.refreshAllObjects()
                                repairContext.reset()
                            }
                            throw error
                        }
                        
                        await repairContext.perform {
                            repairContext.refreshAllObjects()
                            repairContext.reset()
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
                        
                    } catch {
                        await backgroundContext.perform {
                            backgroundContext.rollback()
                            backgroundContext.refreshAllObjects()
                            backgroundContext.reset()
                        }
                        
                        await MainActor.run {
                            Self.log(
                                "❌ Listener batch failed: \(error.localizedDescription)",
                                level: .error,
                                collection: collectionName
                            )
                        }
                    }
                    
                    // -----------------------------------------
                    // Final cleanup
                    // -----------------------------------------
                    await backgroundContext.perform {
                        backgroundContext.refreshAllObjects()
                        backgroundContext.reset()
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
            await context.perform {
                deleteEntityByStringID(
                    ofType: PirateIsland.self,
                    idString: change.document.documentID,
                    fieldName: "islandID",
                    context: context
                )
            }

            await MainActor.run {
                _ = FirestoreSyncManager.shared
                    .pirateIslandCache
                    .removeValue(forKey: change.document.documentID)
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
            await context.perform {
                deleteEntityByUUID(
                    ofType: Review.self,
                    idString: change.document.documentID,
                    fieldName: "reviewID",
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
            await context.perform {
                deleteEntityByStringID(
                    ofType: AppDayOfWeek.self,
                    idString: change.document.documentID,
                    fieldName: "appDayOfWeekID",
                    context: context
                )
            }

            await MainActor.run {
                _ = FirestoreSyncManager.shared
                    .appDayCache
                    .removeValue(forKey: change.document.documentID)
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
            await context.perform {
                deleteEntityByUUID(
                    ofType: MatTime.self,
                    idString: change.document.documentID,
                    fieldName: "id",
                    context: context
                )
            }
        }
    }
    
    // MARK: - Delete helpers
    nonisolated private static func deleteEntityByStringID<T: NSManagedObject>(
        ofType type: T.Type,
        idString: String,
        fieldName: String,
        context: NSManagedObjectContext
    ) {
        let fetchRequest = NSFetchRequest<T>(
            entityName: String(describing: type)
        )
        
        fetchRequest.predicate = NSPredicate(
            format: "%K == %@",
            fieldName,
            idString
        )
        
        fetchRequest.fetchLimit = 1
        
        do {
            if let object = try context.fetch(fetchRequest).first {
                context.delete(object)
                context.processPendingChanges()
                
                Task { @MainActor in
                    Self.log(
                        "🗑️ SUCCESSFULLY DELETED \(type): \(idString)",
                        level: .success,
                        collection: String(describing: type)
                    )
                }
            } else {
                Task { @MainActor in
                    Self.log(
                        "❌ DELETE FAILED — NOT FOUND: \(idString)",
                        level: .error,
                        collection: String(describing: type)
                    )
                }
            }
        } catch {
            
            Task { @MainActor in
                Self.log(
                    "❌ DELETE ERROR: \(error)",
                    level: .error,
                    collection: String(describing: type)
                )
            }
        }
    }
    
    nonisolated private static func deleteEntityByUUID<T: NSManagedObject>(
        ofType type: T.Type,
        idString: String,
        fieldName: String,
        context: NSManagedObjectContext
    ) {
        let uuid = UUID(uuidString: idString) ?? UUID.fromStringID(idString)
        
        let fetchRequest = NSFetchRequest<T>(
            entityName: String(describing: type)
        )
        
        fetchRequest.predicate = NSPredicate(
            format: "%K == %@",
            fieldName,
            uuid as CVarArg
        )
        
        fetchRequest.fetchLimit = 1
        
        do {
            if let object = try context.fetch(fetchRequest).first {
                context.delete(object)
                context.processPendingChanges()
                
                Task { @MainActor in
                    Self.log(
                        "🗑️ SUCCESSFULLY DELETED \(type): \(uuid.uuidString)",
                        level: .success,
                        collection: String(describing: type)
                    )
                }
            } else {
                Task { @MainActor in
                    Self.log(
                        "❌ DELETE FAILED — NOT FOUND: \(idString)",
                        level: .error,
                        collection: String(describing: type)
                    )
                }
            }
        } catch {
            
            Task { @MainActor in
                Self.log(
                    "❌ DELETE ERROR: \(error)",
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

    /// Deterministic UUID from any string (Firestore-safe)
    static func fromStringID(_ string: String) -> UUID {

        // If already a UUID → use it directly
        if let uuid = UUID(uuidString: string) {
            return uuid
        }

        // ✅ Stable hash (unlike Hasher)
        let digest = SHA256.hash(data: Data(string.utf8))

        // Take first 16 bytes for UUID
        let bytes = Array(digest.prefix(16))

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
