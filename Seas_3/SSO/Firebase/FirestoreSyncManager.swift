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

        // DOWNLOAD: Pass only the records relevant to the current collectionName
        await downloadFirestoreRecordsToLocal(collectionName: collectionName, records: firestoreRecordsNotInLocal)
    }

    // New function to download Firestore records to Core Data
    private func downloadFirestoreRecordsToLocal(collectionName: String, records: [String]) async {
        print("Downloading Firestore records to local Core Data for collection: \(collectionName)")

        let context = PersistenceController.shared.container.newBackgroundContext()
        let db = Firestore.firestore()
        let collectionRef = db.collection(collectionName)

        for record in records {
            let docRef = collectionRef.document(record)

            do {
                let docSnapshot = try await docRef.getDocument()

                guard docSnapshot.exists else {
                    print("Firestore document does not exist for record: \(record)")
                    continue
                }

                // Add this line to log the raw Firestore data
                print("🔵 Firestore data for \(collectionName) record \(record): \(docSnapshot.data() ?? [:])")

                await context.perform { [self] in
                    var managedObject: NSManagedObject? = nil

                    switch collectionName {
                    case "pirateIslands":
                        var pirateIsland = fetchPirateIslandByID(record, in: context)
                        if pirateIsland == nil {
                            pirateIsland = PirateIsland(context: context)
                            pirateIsland?.islandID = UUID(uuidString: record)
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
                                print("🟡 Creating new MatTime with ID: \(record)")
                            } else {
                                print("❌ Error: Invalid UUID string for MatTime ID: \(record). Skipping creation.")
                                return
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

                            // Link MatTime to AppDayOfWeek using Firestore DocumentReference
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
                        print("Unknown collection: \(collectionName)")
                        return
                    }

                    if let obj = managedObject {
                        do {
                            try obj.validateForInsert()
                            try obj.validateForUpdate()
                        } catch let validationError as NSError {
                            print("❌ CORE DATA VALIDATION ERROR for \(collectionName) record \(record): \(validationError.localizedDescription)")
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
                            return
                        }
                    }

                    do {
                        try context.save()
                        print("✅ Synced \(collectionName) record \(record) to Core Data.")
                    } catch {
                        print("❌ Error syncing \(collectionName) record \(record): \(error.localizedDescription)")
                        let nsError = error as NSError
                        print("    - Core Data Error Code: \(nsError.code)")
                        print("    - Core Data User Info: \(nsError.userInfo)")

                        if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
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
                        context.rollback()
                    }
                }
            } catch {
                print("❌ Error fetching Firestore document for \(collectionName) record \(record): \(error.localizedDescription)")
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
