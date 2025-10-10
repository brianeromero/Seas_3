//
//  FirestoreSyncManager.swift
//  Seas_3
//
//  Created by Brian Romero on 5/23/25.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreData

class FirestoreSyncManager {
    static let shared = FirestoreSyncManager()

    func syncInitialFirestoreData() {
        guard Auth.auth().currentUser != nil else {
            print("❌ No user is signed in. Firestore access is restricted.")
            return
        }

        Task {
            do {
                try await createFirestoreCollection() // This creates/checks collections

                let db = Firestore.firestore()

                // Get all Firestore document IDs for pirateIslands
                let pirateIslandSnapshot = try await db.collection("pirateIslands").getDocuments()
                let pirateIslandFirestoreIDs = pirateIslandSnapshot.documents.map { $0.documentID }
                await downloadFirestoreRecordsToLocal(collectionName: "pirateIslands", records: pirateIslandFirestoreIDs)

                // Get all Firestore document IDs for reviews
                let reviewsSnapshot = try await db.collection("reviews").getDocuments()
                let reviewsFirestoreIDs = reviewsSnapshot.documents.map { $0.documentID }
                await downloadFirestoreRecordsToLocal(collectionName: "reviews", records: reviewsFirestoreIDs)

                // Continue for AppDayOfWeek and MatTime (ensuring order if dependencies exist)
                let appDayOfWeekSnapshot = try await db.collection("AppDayOfWeek").getDocuments()
                let appDayOfWeekFirestoreIDs = appDayOfWeekSnapshot.documents.map { $0.documentID }
                await downloadFirestoreRecordsToLocal(collectionName: "AppDayOfWeek", records: appDayOfWeekFirestoreIDs)

                let matTimesSnapshot = try await db.collection("MatTime").getDocuments() // Note: your collection name is "MatTime" not "matTimes"
                let matTimesFirestoreIDs = matTimesSnapshot.documents.map { $0.documentID }
                await downloadFirestoreRecordsToLocal(collectionName: "MatTime", records: matTimesFirestoreIDs)

            } catch {
                print("❌ Firestore sync error: \(error.localizedDescription)")
            }
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
        print("🚀 [SyncManager] Initiating record check for collection: \(collectionName)")

        // ✅ Step 1: Check for network connection before doing anything
        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ [SyncManager] No network connection detected. Skipping Firestore sync for \(collectionName).")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                    "message": "No internet connection. Sync postponed until you're back online.",
                    "type": ToastView.ToastType.info.rawValue
                ])
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

        // DOWNLOAD: Pass only the records relevant to the current collectionName
        await downloadFirestoreRecordsToLocal(collectionName: collectionName, records: firestoreRecordsNotInLocal)
    }

    // New function to download Firestore records to Core Data
    private func downloadFirestoreRecordsToLocal(collectionName: String, records: [String]) async {
        print("Downloading Firestore records to local Core Data for collection: \(collectionName)")

        // Optional: Toast at the very start of the download process for a collection
        // This could be useful if a collection has many records and takes time
        if !records.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Small delay to not interfere with other immediate toasts
                NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                    "message": "Downloading \(records.count) \(collectionName) from cloud...",
                    "type": ToastView.ToastType.info.rawValue
                ])
                print("📧 [SyncManager] Posted 'ShowToast' notification (info type - downloading start) for \(collectionName).")
            }
        }


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
                    print("❌ Firestore document does not exist for record: \(record). Skipping download.")
                    errorCount += 1
                    continue
                }

                print("🔵 Firestore data for \(collectionName) record \(record): \(docSnapshot.data() ?? [:])")

                await context.perform { [self] in
                    var managedObject: NSManagedObject? = nil
                    var isNewRecord = false // To track if a new record was created

                    switch collectionName {
                    case "pirateIslands":
                        var pirateIsland = fetchPirateIslandByID(record, in: context)
                        if pirateIsland == nil {
                            pirateIsland = PirateIsland(context: context)
                            pirateIsland?.islandID = UUID(uuidString: record)
                            isNewRecord = true
                            print("🟡 Creating new PirateIsland with ID: \(record)")
                        } else {
                            print("🟢 Updating existing PirateIsland with ID: \(record)")
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
                            managedObject = pi
                        }

                    case "reviews":
                        var review = fetchReviewByID(record, in: context)
                        if review == nil {
                            review = Review(context: context)
                            review?.reviewID = UUID(uuidString: record)!
                            isNewRecord = true
                            print("🟡 Creating new Review with ID: \(record)")
                        } else {
                            print("🟢 Updating existing Review with ID: \(record)")
                        }
                        if let r = review {
                            r.stars = docSnapshot.get("stars") as? Int16 ?? 0
                            r.review = docSnapshot.get("review") as? String ?? ""
                            r.userName = docSnapshot.get("userName") as? String ?? docSnapshot.get("name") as? String ?? "Anonymous"
                            r.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue() ?? Date()

                            if let islandIDString = docSnapshot.get("islandID") as? String {
                                if let island = fetchPirateIslandByID(islandIDString, in: context) {
                                    r.island = island
                                    print("🔗 Successfully linked Review \(record) to PirateIsland \(islandIDString).")
                                } else {
                                    print("⚠️ WARNING: Could not find PirateIsland with ID \(islandIDString) for Review \(record). Relationship not set.")
                                }
                            } else {
                                print("⚠️ WARNING: No 'islandID' found in Firestore data for Review \(record).")
                            }
                            managedObject = r
                        }

                    case "MatTime":
                        var matTime = fetchMatTimeByID(record, in: context)
                        if matTime == nil {
                            matTime = MatTime(context: context)
                            if let uuid = UUID(uuidString: record) {
                                matTime?.id = uuid
                                isNewRecord = true
                                print("🟡 Creating new MatTime with ID: \(record)")
                            } else {
                                print("❌ Error: Invalid UUID string for MatTime ID: \(record). Skipping creation.")
                                // Do not return here, just skip managedObject = mt
                            }
                        } else {
                            print("🟢 Updating existing MatTime with ID: \(record)")
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
                                let appDayOfWeekID = appDayOfWeekRef.documentID
                                if let appDayOfWeek = fetchAppDayOfWeekByID(appDayOfWeekID, in: context) {
                                    mt.appDayOfWeek = appDayOfWeek
                                    print("🔗 Successfully linked MatTime \(record) to AppDayOfWeek \(appDayOfWeekID).")
                                } else {
                                    print("⚠️ WARNING: Could not find AppDayOfWeek with ID \(appDayOfWeekID) for MatTime \(record). Relationship not set.")
                                }
                            } else {
                                print("⚠️ WARNING: No 'appDayOfWeek' reference found in Firestore data for MatTime \(record).")
                            }
                            managedObject = mt
                        }

                    case "AppDayOfWeek":
                        var appDayOfWeek = fetchAppDayOfWeekByID(record, in: context)
                        if appDayOfWeek == nil {
                            appDayOfWeek = AppDayOfWeek(context: context)
                            appDayOfWeek?.appDayOfWeekID = record
                            isNewRecord = true
                            print("🟡 Creating new AppDayOfWeek with ID: \(record)")
                        } else {
                            print("🟢 Updating existing AppDayOfWeek with ID: \(record)")
                        }

                        if let ado = appDayOfWeek {
                            ado.day = docSnapshot.get("day") as? String ?? ""
                            ado.name = docSnapshot.get("name") as? String
                            ado.createdTimestamp = (docSnapshot.get("createdTimestamp") as? Timestamp)?.dateValue()

                            if let pIslandData = docSnapshot.get("pIsland") as? [String: Any],
                               let pirateIslandID = pIslandData["islandID"] as? String {
                                if let pirateIsland = fetchPirateIslandByID(pirateIslandID, in: context) {
                                    ado.pIsland = pirateIsland
                                    print("🔗 Successfully linked AppDayOfWeek \(record) to PirateIsland \(pirateIslandID).")
                                } else {
                                    print("⚠️ WARNING: Could not find PirateIsland with ID \(pirateIslandID) for AppDayOfWeek \(record). Creating a stub.")
                                    let newIsland = PirateIsland(context: context)
                                    newIsland.islandID = UUID(uuidString: pirateIslandID)
                                    newIsland.islandName = pIslandData["islandName"] as? String
                                    newIsland.islandLocation = pIslandData["islandLocation"] as? String
                                    newIsland.country = pIslandData["country"] as? String
                                    newIsland.latitude = pIslandData["latitude"] as? Double ?? 0.0
                                    newIsland.longitude = pIslandData["longitude"] as? Double ?? 0.0
                                    ado.pIsland = newIsland
                                }
                            } else {
                                print("⚠️ WARNING: No 'pIsland' or 'islandID' found in Firestore data for AppDayOfWeek \(record).")
                            }

                            if let matTimesArray = docSnapshot.get("matTimes") as? [String] {
                                for matTimeID in matTimesArray {
                                    if let matTime = fetchMatTimeByID(matTimeID, in: context) {
                                        ado.addToMatTimes(matTime)
                                        print("🔗 Added MatTime \(matTimeID) to AppDayOfWeek \(record).")
                                    } else {
                                        print("⚠️ WARNING: Could not find MatTime with ID \(matTimeID) for AppDayOfWeek \(record). Not linking.")
                                    }
                                }
                            } else {
                                print("⚠️ WARNING: No 'matTimes' found in Firestore data for AppDayOfWeek \(record).")
                            }
                            managedObject = ado
                        }

                    default:
                        print("Unknown collection: \(collectionName). Skipping record \(record).")
                        errorCount += 1
                        return // Exit perform block for this record
                    }

                    if let obj = managedObject {
                        do {
                            try obj.validateForInsert()
                            try obj.validateForUpdate()
                            try context.save()
                            print("✅ Synced \(collectionName) record \(record) to Core Data.")
                            downloadedCount += 1 // Increment success count
                        } catch let validationError as NSError {
                            print("❌ CORE DATA VALIDATION ERROR for \(collectionName) record \(record): \(validationError.localizedDescription)")
                            errorCount += 1 // Increment error count
                            if let detailedErrors = validationError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                                for detailedError in detailedErrors {
                                    print("    - Detailed Error: \(detailedError.localizedDescription)")
                                    if let key = detailedError.userInfo["NSValidationErrorKey"] {
                                        print("      Attribute/Relationship Key: \(key)")
                                    }
                                    if let value = detailedError.userInfo["NSValidationErrorValue"] {
                                        print("      Invalid Value: \(value)")
                                    }
                                }
                            }
                            context.rollback() // Rollback changes for this record
                        } catch {
                            print("❌ Error saving \(collectionName) record \(record) to Core Data: \(error.localizedDescription)")
                            errorCount += 1 // Increment error count
                            let nsError = error as NSError
                            print("    - Core Data Error Code: \(nsError.code)")
                            print("    - Core Data User Info: \(nsError.userInfo)")
                            context.rollback() // Rollback changes for this record
                        }
                    } else {
                        print("⚠️ No managed object created/found for \(collectionName) record \(record). Skipping save.")
                        errorCount += 1
                    }
                } // end await context.perform
            } catch {
                print("❌ Error fetching Firestore document for \(collectionName) record \(record): \(error.localizedDescription)")
                errorCount += 1
            }
        } // end for record in records

        // Final toast for the download operation
        if !records.isEmpty { // Only show if there were records to attempt to download
            if errorCount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                        "message": "Successfully downloaded \(downloadedCount) \(collectionName) records.",
                        "type": ToastView.ToastType.success.rawValue
                    ])
                    print("📧 [SyncManager] Posted 'ShowToast' notification (success type - download complete) for \(collectionName).")
                }
            } else if downloadedCount > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                        "message": "Downloaded \(downloadedCount) \(collectionName) records, \(errorCount) failed.",
                        "type": ToastView.ToastType.info.rawValue // Info or error depending on severity
                    ])
                    print("📧 [SyncManager] Posted 'ShowToast' notification (info type - partial download) for \(collectionName).")
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: Notification.Name("ShowToast"), object: nil, userInfo: [
                        "message": "Failed to download any \(collectionName) records. Check logs.",
                        "type": ToastView.ToastType.error.rawValue
                    ])
                    print("📧 [SyncManager] Posted 'ShowToast' notification (error type - download failed) for \(collectionName).")
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
