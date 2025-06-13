// AppDayOfWeekViewModel.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Foundation
import Combine
import CoreData
import FirebaseFirestore



class AppDayOfWeekViewModel: ObservableObject, Equatable {
    @Published var currentAppDayOfWeek: AppDayOfWeek?
    @Published var selectedIsland: PirateIsland?
    @Published var matTime: MatTime?
    @Published var islandsWithMatTimes: [(PirateIsland, [MatTime])] = []
    @Published var islandSchedules: [DayOfWeek: [(PirateIsland, [MatTime])]] = [:]
    var enterZipCodeViewModel: EnterZipCodeViewModel
    @Published var matTimesForDay: [DayOfWeek: [MatTime]] = [:]
    
    @Published var appDayOfWeekList: [AppDayOfWeek] = []
    @Published var appDayOfWeekID: String?
    @Published var saveEnabled: Bool = false
    @Published var schedules: [DayOfWeek: [AppDayOfWeek]] = [:]
    @Published var allIslands: [PirateIsland] = []
    @Published var errorMessage: String?
    @Published var newMatTime: MatTime?
    
    var viewContext: NSManagedObjectContext
    private let dataManager: PirateIslandDataManager
    public var repository: AppDayOfWeekRepository
    private let firestore = Firestore.firestore()

    
    // MARK: - Day Settings
    @Published var dayOfWeekStates: [DayOfWeek: Bool] = [:]
    @Published var giForDay: [DayOfWeek: Bool] = [:]
    @Published var noGiForDay: [DayOfWeek: Bool] = [:]
    @Published var openMatForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionsForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionDescriptionForDay: [DayOfWeek: String] = [:]
    @Published var goodForBeginnersForDay: [DayOfWeek: Bool] = [:]
    @Published var kidsForDay: [DayOfWeek: Bool] = [:]
    @Published var matTimeForDay: [DayOfWeek: String] = [:]
    @Published var selectedTimeForDay: [DayOfWeek: Date] = [:]
    @Published var showError = false
    @Published var selectedAppDayOfWeek: AppDayOfWeek?
    
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    
    // MARK: - Property Observers
    @Published var name: String? {
        didSet {
            print("Name updated: \(name ?? "None")")
            handleUserInteraction()
        }
    }
    
    @Published var selectedType: String = "" {
        didSet {
            print("Selected type updated: \(selectedType)")
            handleUserInteraction()
        }
    }
    
    @Published var selectedDay: DayOfWeek? {
        didSet {
            handleUserInteraction()
        }
    }
    
    // MARK: - DateFormatter
    public let dateFormatter: DateFormatter = DateFormat.time
    
    
    // MARK: - Initializer
    init(selectedIsland: PirateIsland? = nil, repository: AppDayOfWeekRepository, enterZipCodeViewModel: EnterZipCodeViewModel) {
        self.selectedIsland = selectedIsland
        self.repository = repository
        self.viewContext = repository.getViewContext() // Initialize viewContext using repository method
        self.dataManager = PirateIslandDataManager(viewContext: self.viewContext)
        self.enterZipCodeViewModel = enterZipCodeViewModel
        
        print("AppDayOfWeekViewModel initialized with repository: \(repository)")
        
        // Initialization logic
        fetchPirateIslands()
        initializeDaySettings()
    }
    
    // Method to fetch AppDayOfWeek later
    func updateDayAndFetch(day: DayOfWeek) async {
        guard let island = selectedIsland else {
            print("Island is not set.")
            return
        }

        // Assuming fetchCurrentDayOfWeek returns values and might do async work
        let (appDayOfWeek, matTimes) = await fetchCurrentDayOfWeek(for: island, day: day, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 ?? .monday }))

        if appDayOfWeek != nil && matTimes != nil {
            print("Updated day and fetched MatTimes.")
        } else {
            print("Failed to update day and fetch MatTimes.")
        }
    }
    
    
    // MARK: - Methods
    func saveData() async {
        print("Saving data...")
        do {
            try await PersistenceController.shared.saveContext()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
    
    func saveAppDayOfWeekLocally() {
        guard let island = selectedIsland,
              let appDayOfWeek = currentAppDayOfWeek,
              let dayOfWeek = selectedDay else {
            errorMessage = "Gym, AppDayOfWeek, or DayOfWeek is not selected."
            print("Gym, AppDayOfWeek, or DayOfWeek is not selected.")
            return
        }

        // Check if name is nil and generate it if necessary
        if appDayOfWeek.name == nil {
            appDayOfWeek.name = AppDayOfWeekRepository.shared.generateName(for: island, day: dayOfWeek)
        }

        // Use the repository to save the AppDayOfWeek data
        repository.updateAppDayOfWeek(appDayOfWeek, with: island, dayOfWeek: dayOfWeek, context: viewContext)
    }

    func saveAppDayOfWeekToFirestore(selectedIslandID: NSManagedObjectID, selectedDay: DayOfWeek, appDayOfWeekObjectID: NSManagedObjectID) async throws {
        print("📣 saveAppDayOfWeekToFirestore() called with AppDayOfWeek ID: \(appDayOfWeekObjectID)")

        // Outer continuation: Make the entire `saveAppDayOfWeekToFirestore` function async.
        // This bridges the synchronous Core Data `performBackgroundTask` call.
        try await withCheckedThrowingContinuation { (outerContinuation: CheckedContinuation<Void, Error>) in

            // Step 1: Perform background task. This closure MUST be synchronous.
            PersistenceController.shared.container.performBackgroundTask { backgroundContext in

                // Inner continuation: Make the `backgroundContext.perform` call async (from an awaiter's perspective).
                // This closure MUST also be synchronous.
                backgroundContext.perform { // Use `perform` (async completion) instead of `performAndWait` if possible
                                            // to avoid blocking the background queue for too long, but handle its completion.

                    // All Core Data operations that touch NSManagedObjects must be within this `perform` block.
                    do {
                        guard let appDayOfWeekOnBG = try backgroundContext.existingObject(with: appDayOfWeekObjectID) as? AppDayOfWeek else {
                            let error = NSError(domain: "AppDayOfWeekViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate AppDayOfWeek in background context."])
                            print("🚫 \(error.localizedDescription)")
                            throw error
                        }

                        guard let selectedIslandOnBG = try backgroundContext.existingObject(with: selectedIslandID) as? PirateIsland else {
                            let error = NSError(domain: "AppDayOfWeekViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate selectedIsland in background context."])
                            print("🚫 \(error.localizedDescription)")
                            throw error
                        }

                        print("🛠️ Preparing to save AppDayOfWeek to Firestore...")

                        var extendedData = appDayOfWeekOnBG.toFirestoreData()

                        if let pirateIslandData = selectedIslandOnBG.toFirestoreData() {
                            extendedData["pIsland"] = pirateIslandData
                            print("✅ Added PirateIsland data: \(pirateIslandData)")
                        } else {
                            print("⚠️ Could not convert selectedIsland to Firestore data.")
                        }

                        print("📦 Data being saved: \(extendedData)")

                        guard let appDayOfWeekFirestoreID = appDayOfWeekOnBG.appDayOfWeekID else {
                            let error = NSError(domain: "AppDayOfWeekViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "appDayOfWeekID is nil — can't save to Firestore."])
                            print("🚫 \(error.localizedDescription)")
                            throw error
                        }

                        let appDayRef = self.firestore.collection("AppDayOfWeek").document(appDayOfWeekFirestoreID)
                        print("📄 Firestore reference path: \(appDayRef.path)")

                        // Using a dedicated Task here to sequence the async Firestore calls
                        // within the synchronous `backgroundContext.perform` block.
                        Task {
                            do {
                                // 4. Save the main `AppDayOfWeek` document
                                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                    appDayRef.setData(extendedData) { error in
                                        if let error = error {
                                            print("🔥 Failed to save AppDayOfWeek: \(error.localizedDescription) | Path: \(appDayRef.path)")
                                            continuation.resume(throwing: error)
                                        } else {
                                            print("✅ AppDayOfWeek saved successfully at: \(appDayRef.path)")
                                            continuation.resume(returning: ())
                                        }
                                    }
                                }

                                // 5. Save matTimes as sub-collection
                                let matTimesRef = appDayRef.collection("matTimes")

                                print("🗑️ Deleting existing MatTimes sub-collection...")
                                let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot?, Error>) in
                                    matTimesRef.getDocuments { snapshot, error in
                                        if let error = error { // Correct way to unwrap a non-nil error
                                            continuation.resume(throwing: error) // Resume with the error
                                        } else {
                                            // If error is nil, it means success. You can safely return the snapshot.
                                            continuation.resume(returning: snapshot) // Snapshot might be nil if no documents
                                        }
                                    }
                                }

                                if let snapshot = snapshot {
                                    for doc in snapshot.documents {
                                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                            doc.reference.delete { deleteError in
                                                if let deleteError = deleteError {
                                                    continuation.resume(throwing: deleteError)
                                                } else {
                                                    print("🗑️ Deleted old MatTime document: \(doc.documentID)")
                                                    continuation.resume(returning: ())
                                                }
                                            }
                                        }
                                    }
                                    print("🗑️ Finished deleting \(snapshot.documents.count) existing MatTimes.")
                                }

                                // 6. Add new matTimes as sub-documents
                                if let matTimes = appDayOfWeekOnBG.matTimes as? Set<MatTime> {
                                    print("🛠️ Saving \(matTimes.count) new MatTime documents...")

                                    for matTime in matTimes {
                                        let matTimeData = matTime.toFirestoreData()

                                        guard let matTimeUUIDString = matTime.id?.uuidString else {
                                            print("⚠️ MatTime has no UUID for Firestore document name. Skipping: \(matTime)")
                                            continue
                                        }

                                        let matTimeDocumentRef = matTimesRef.document(matTimeUUIDString)

                                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                                            matTimeDocumentRef.setData(matTimeData) { matTimeError in
                                                if let matTimeError = matTimeError {
                                                    print("🔥 Failed to save MatTime \(matTimeUUIDString): \(matTimeError.localizedDescription)")
                                                    continuation.resume(throwing: matTimeError)
                                                } else {
                                                    print("✅ MatTime \(matTimeUUIDString) saved successfully.")
                                                    continuation.resume(returning: ())
                                                }
                                            }
                                        }
                                    }
                                    print("✅ All new MatTimes saved.")
                                } else {
                                    print("ℹ️ No matTimes to save for AppDayOfWeek: \(appDayOfWeekOnBG.name ?? "nil")")
                                }
                                print("💾 Core Data changes should auto-merge from background context.")

                                // If all async operations within the Task succeed,
                                // resume the outer continuation with success.
                                outerContinuation.resume(returning: ())

                            } catch {
                                // If any error occurred within the async Task,
                                // resume the outer continuation with that error.
                                outerContinuation.resume(throwing: error)
                            }
                        } // END OF: Task { ... }

                    } catch {
                        // Catch Core Data errors that occur synchronously
                        outerContinuation.resume(throwing: error)
                    }
                } // END OF: backgroundContext.perform { ... }
            } // END OF: PersistenceController.shared.container.performBackgroundTask { ... }
        } // END OF: withCheckedThrowingContinuation { ... }
    }

    // Assuming this is still in AppDayOfWeekViewModel
    @MainActor // Mark it as MainActor since it accesses @Published properties
    func saveAppDayOfWeek() async { // Make it async
        guard let selectedIsland = selectedIsland,
              let selectedDay = selectedDay,
              let appDayOfWeekToSave = currentAppDayOfWeek // You need an existing AppDayOfWeek to save its ID
        else {
            print("🚫 Missing data for saving AppDayOfWeek: Gym: \(selectedIsland != nil), DayOfWeek: \(selectedDay != nil), AppDayOfWeek: \(currentAppDayOfWeek != nil)")
            return
        }

        do {
            // Call the refactored Firestore save function with ObjectIDs
            try await saveAppDayOfWeekToFirestore(
                selectedIslandID: selectedIsland.objectID,
                selectedDay: selectedDay,
                appDayOfWeekObjectID: appDayOfWeekToSave.objectID // Pass the ObjectID of the AppDayOfWeek
            )
            print("✅ AppDayOfWeek saved from direct call.")
        } catch {
            print("❌ Error saving AppDayOfWeek from direct call: \(error.localizedDescription)")
            self.errorMessage = "Failed to save AppDayOfWeek: \(error.localizedDescription)"
            self.showError = true // Assuming you have a way to show error
        }
    }
    
    func fetchPirateIslands() {
        print("Fetching gyms...")
        let result = dataManager.fetchPirateIslands()
        switch result {
        case .success(let pirateIslands):
            allIslands = pirateIslands
            print("Fetched Gyms: \(allIslands)")
        case .failure(let error):
            print("Error fetching gyms: \(error.localizedDescription)")
            errorMessage = "Error fetching gyms: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Ensure Initialization
    func ensureInitialization() async {
        if selectedIsland == nil {
            errorMessage = "Island is not selected."
            print("Error: Island is not selected.")
            return
        }
        
        // Ensure you have a valid day
        guard let selectedDay = selectedDay else {
            errorMessage = "Day is not selected."
            print("Error: Day is not selected.")
            return
        }
        
        let (appDayOfWeek, matTimes) = await fetchCurrentDayOfWeek(for: selectedIsland!, day: selectedDay, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 ?? .monday }))
        
        if appDayOfWeek != nil && matTimes != nil {
            print("Current day of the week initialized.")
        } else {
            print("Failed to fetch current day of the week.")
        }
    }
    
    // MARK: - Fetch Current Day Of Week
    // Populates the matTimesForDay dictionary with the scheduled mat times for each day
    @MainActor
    func fetchCurrentDayOfWeek(for island: PirateIsland, day: DayOfWeek, selectedDayBinding: Binding<DayOfWeek?>) async -> (AppDayOfWeek?, [MatTime]?) {
        print("Fetching current day of week for island: \(island.islandName ?? ""), day: \(day)")

        let context = repository.getViewContext()

        // Step 1: Check Core Data
        if let existingAppDayOfWeek = repository.fetchAppDayOfWeek(for: day.rawValue, pirateIsland: island, context: context) {
            print("✅ Found AppDayOfWeek in Core Data")
            selectedDayBinding.wrappedValue = day
            return (existingAppDayOfWeek, existingAppDayOfWeek.matTimes?.allObjects as? [MatTime] ?? [])
        }

        print("❌ Not found in Core Data. Checking Firestore...")

        // Step 2: Check Firestore
        do {
            let document = try await firestore.collection("appDayOfWeek").document(day.rawValue).getDocument()
            
            if let data = document.data() {
                print("✅ Found AppDayOfWeek in Firestore")

                // Fetch or create in Core Data but do not create a new Firestore entry
                if let newAppDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: day.rawValue, pirateIsland: island, context: context) {
                    newAppDayOfWeek.configure(data: data) // Populate with Firestore data

                    // Save Core Data context
                    try context.save()

                    selectedDayBinding.wrappedValue = day
                    return (newAppDayOfWeek, newAppDayOfWeek.matTimes?.allObjects as? [MatTime] ?? [])
                }
            } else {
                print("❌ Not found in Firestore either.")
            }
        } catch {
            print("❌ Error fetching from Firestore: \(error.localizedDescription)")
        }

        // 🚨 Show alert message if no data exists
        alertTitle = "No Mat Times Available"
        alertMessage = "No mat times have been entered for \(day.displayName) at \(island.islandName ?? "this gym")."
        showAlert = true

        print("❌ No AppDayOfWeek found")
        return (nil, nil)
    }



    // MARK: - Add or Update Mat Time
    func addOrUpdateMatTime(
        time: String,
        type: String,
        gi: Bool,
        noGi: Bool,
        openMat: Bool,
        restrictions: Bool,
        restrictionDescription: String? = "OOGA BOOOGA1", // Default value
        goodForBeginners: Bool,
        kids: Bool,
        for day: DayOfWeek
    ) async {
        guard selectedIsland != nil else {
            print("Error: Selected gym is not set. Please select a gym before adding a mat time.")
            return
        }
        await addMatTimes(day: day, matTimes: [
            (time: time, type: type, gi: gi, noGi: noGi, openMat: openMat, restrictions: restrictions, restrictionDescription: restrictionDescription, goodForBeginners: goodForBeginners, kids: kids)
        ])
        print("Added/Updated MatTime")
    }
    

    // MARK: - Update Or Create MatTime
    func updateOrCreateMatTime(
        _ existingMatTimeID: NSManagedObjectID?, // <-- Now takes an ID
        time: String,
        type: String,
        gi: Bool,
        noGi: Bool,
        openMat: Bool,
        restrictions: Bool,
        restrictionDescription: String,
        goodForBeginners: Bool,
        kids: Bool,
        for appDayOfWeekID: NSManagedObjectID // <-- Now takes an ID
    ) async throws -> NSManagedObjectID { // <-- Now returns an ID
        // 1. Get a new background context for this write operation
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()

        let matTimeID = try await backgroundContext.perform { // Perform all Core Data operations on this context
            print("Using updateOrCreateMatTime, updating/creating MatTime for AppDayOfWeek with ID: \(appDayOfWeekID)")

            // Rehydrate appDayOfWeek on this background context
            guard let appDayOfWeek = try backgroundContext.existingObject(with: appDayOfWeekID) as? AppDayOfWeek else {
                throw NSError(domain: "CoreDataError", code: 200, userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate AppDayOfWeek in background context."])
            }

            appDayOfWeek.name = appDayOfWeek.day // This is fine as it's on the right context
            let matTime: MatTime

            if let existingID = existingMatTimeID {
                // Rehydrate existingMatTime on this background context
                guard let existing = try backgroundContext.existingObject(with: existingID) as? MatTime else {
                    throw NSError(domain: "CoreDataError", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate existing MatTime in background context."])
                }
                matTime = existing
            } else {
                matTime = MatTime(context: backgroundContext) // Create on background context
                matTime.configure(
                    time: time,
                    type: type,
                    gi: gi,
                    noGi: noGi,
                    openMat: openMat,
                    restrictions: restrictions,
                    restrictionDescription: restrictionDescription,
                    goodForBeginners: goodForBeginners,
                    kids: kids
                )
                matTime.createdTimestamp = Date()
            }

            if matTime.id == nil {
                matTime.id = UUID()
            }

            if existingMatTimeID == nil { // If it's a new MatTime
                appDayOfWeek.addToMatTimes(matTime) // Add to relationship on background context
                print("Added new MatTime to AppDayOfWeek in background context.")
            }

            if backgroundContext.hasChanges {
                try backgroundContext.save() // Save the background context
                print("Background context saved successfully for MatTime and AppDayOfWeek.")
            }

            // Return the objectID, not the object itself
            return matTime.objectID
        }

        // Call refreshMatTimes if it needs to update UI based on these changes.
        // Ensure refreshMatTimes is thread-safe or calls MainActor.run for UI updates.
        await refreshMatTimes()
        return matTimeID
    }


    // MARK: - Refresh MatTimes
    func refreshMatTimes() async {
        print("Refreshing MatTimes")
        if let selectedIsland = selectedIsland, let unwrappedSelectedDay = selectedDay {
            // Fetch and assign the current day of the week
            let (appDayOfWeek, matTimes) = await fetchCurrentDayOfWeek(for: selectedIsland, day: unwrappedSelectedDay, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 ?? .monday }))
            
            if appDayOfWeek != nil && matTimes != nil {
                print("MatTimes refreshed successfully.")
            } else {
                print("Failed to refresh MatTimes.")
            }
        } else {
            print("Error: Either island or day is not selected.")
        }
        await initializeNewMatTime()
    }
    
    // MARK: - Fetch MatTimes for Day
    func fetchMatTimes(for day: DayOfWeek) throws -> [MatTime] {
        print("Fetching MatTimes for day: \(day)")
        
        let request: NSFetchRequest<MatTime> = MatTime.fetchRequest()
        request.entity = NSEntityDescription.entity(forEntityName: "MatTime", in: viewContext)!
        request.predicate = NSPredicate(format: "appDayOfWeek.day ==[c] %@", day.rawValue)
        
        // Apply sort descriptor
        let sortDescriptor = NSSortDescriptor(keyPath: \MatTime.time, ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            throw FetchError.failedToFetchMatTimes(error)
        }
    }
    
    
    @MainActor
    func updateMatTime(_ matTime: MatTime) async throws {
        guard let appDayOfWeek = matTime.appDayOfWeek else {
            print("❌ MatTime has no associated AppDayOfWeek")
            throw NSError(domain: "AppDayOfWeekViewModel", code: 4, userInfo: [NSLocalizedDescriptionKey: "MatTime has no associated AppDayOfWeek."])
        }

        // Call updateOrCreateMatTime with the ObjectIDs
        let updatedMatTimeObjectID = try await updateOrCreateMatTime(
            matTime.objectID, // Pass the ObjectID of the existing MatTime
            time: matTime.time ?? "",
            type: matTime.type ?? "",
            gi: matTime.gi,
            noGi: matTime.noGi,
            openMat: matTime.openMat,
            restrictions: matTime.restrictions,
            restrictionDescription: matTime.restrictionDescription ?? "",
            goodForBeginners: matTime.goodForBeginners,
            kids: matTime.kids,
            for: appDayOfWeek.objectID // Pass the ObjectID of the associated AppDayOfWeek
        )

        print("✅ Mat time updated locally (ObjectID): \(updatedMatTimeObjectID)")

        // Now, you need to trigger the Firestore sync.
        // The `saveAppDayOfWeekToFirestore` function already handles updating the AppDayOfWeek
        // and its nested MatTimes subcollection. So, you should call that.
        guard let selectedIsland = self.selectedIsland else {
            print("❌ Missing selectedIsland for Firestore sync.")
            throw NSError(domain: "AppDayOfWeekViewModel", code: 5, userInfo: [NSLocalizedDescriptionKey: "Missing selectedIsland for Firestore sync."])
        }
        
        guard let selectedDayForAppDayOfWeek = DayOfWeek(rawValue: appDayOfWeek.day) else {
            print("❌ Could not determine selectedDay from AppDayOfWeek for Firestore sync.")
            throw NSError(domain: "AppDayOfWeekViewModel", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not determine selectedDay for Firestore sync."])
        }

        print("📤 Syncing MatTime update to Firestore via saveAppDayOfWeekToFirestore...")
        try await saveAppDayOfWeekToFirestore(
            selectedIslandID: selectedIsland.objectID,
            selectedDay: selectedDayForAppDayOfWeek,
            appDayOfWeekObjectID: appDayOfWeek.objectID
        )
        print("✅ Firestore update successful via saveAppDayOfWeekToFirestore.")

        // Remove the old manual Firestore update logic since saveAppDayOfWeekToFirestore now handles it.
        /*
        guard let matTimeID = updatedMatTime.id?.uuidString else { // updatedMatTime is now an ObjectID, so this is wrong
            print("❌ Missing matTime ID")
            return
        }

        var matTimeData = updatedMatTime.toFirestoreData() // updatedMatTime is now an ObjectID, so this is wrong
        matTimeData["appDayOfWeek"] = Firestore.firestore()
            .collection("AppDayOfWeek")
            .document(appDayOfWeek.appDayOfWeekID ?? "")

        let matTimeRef = Firestore.firestore()
            .collection("MatTime")
            .document(matTimeID)

        print("📤 Updating MatTime in Firestore: \(matTimeID)")
        try await matTimeRef.setData(matTimeData, merge: true)
        print("✅ Firestore update successful.")
        */
    }

    
    // MARK: - Update Day
    func updateDay(for island: PirateIsland, dayOfWeek: DayOfWeek) async {
        print("Updating day settings for gym: \(island) and dayOfWeek: \(dayOfWeek)")
        
        // Fetch or create the AppDayOfWeek instance with context
        let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: dayOfWeek.rawValue, pirateIsland: island, context: viewContext)
        
        // Safely unwrap appDayOfWeek before passing it to the update method
        if let appDayOfWeek = appDayOfWeek {
            repository.updateAppDayOfWeek(appDayOfWeek, with: island, dayOfWeek: dayOfWeek, context: viewContext)
            
            // Update Firestore
            do {
                try await firestore.collection("appDayOfWeek").document(dayOfWeek.rawValue).setData([
                    "day": dayOfWeek.rawValue,
                    "name": appDayOfWeek.name ?? "",
                    "appDayOfWeekID": appDayOfWeek.appDayOfWeekID ?? "",
                    "pIsland": island.islandID ?? ""
                ])
            } catch {
                print("Failed to update AppDayOfWeek in Firestore: \(error.localizedDescription)")
            }
            
            await saveData()
            await refreshMatTimes() // Added await here
        } else {
            // Handle the case where appDayOfWeek is nil, if needed
            print("Failed to fetch or create AppDayOfWeek4.")
        }
    }
    
    // MARK: - Initialize Day Settings
    func initializeDaySettings() {
        print("Initializing day settings")
        let allDays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        for day in allDays {
            dayOfWeekStates[day] = false
            giForDay[day] = false
            noGiForDay[day] = false
            openMatForDay[day] = false
            restrictionsForDay[day] = false
            restrictionDescriptionForDay[day] = ""
            goodForBeginnersForDay[day] = false
            kidsForDay[day] = false
            matTimeForDay[day] = ""
            selectedTimeForDay[day] = Date()
            matTimesForDay[day] = []
        }
        print("Day settings initialized: \(dayOfWeekStates)")
    }
    // MARK: - Initialize New MatTime
    func initializeNewMatTime() async {
        print("Initializing new MatTime")
        // Dispatch to the main thread
        DispatchQueue.main.async {
            self.newMatTime = MatTime(context: self.viewContext)
        }
    }


    // MARK: - Load Schedules
    @MainActor
    func loadSchedules(for island: PirateIsland) async {
        print("THREAD_LOG: YourViewModel.loadSchedules - START - Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
        
        // This predicate isn't used after being created, so it's fine.
        _ = NSPredicate(format: "pIsland == %@", island)
        
        let appDayOfWeeks = await repository.fetchSchedules(for: island)
        
        print("THREAD_LOG: YourViewModel.loadSchedules - After fetchSchedules. Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
        
        var schedulesDict: [DayOfWeek: [AppDayOfWeek]] = [:]
        
        for appDayOfWeek in appDayOfWeeks {
            if appDayOfWeek.day.isEmpty {
                print("Warning: AppDayOfWeek has no day set.")
                continue
            }
            
            do {
                guard let day = DayOfWeek(rawValue: appDayOfWeek.day.lowercased()) else {
                    throw DayOfWeekError.invalidDayValue
                }
                schedulesDict[day, default: []].append(appDayOfWeek)
            } catch DayOfWeekError.invalidDayValue {
                print("Error loading schedules: Invalid day value '\(appDayOfWeek.day)'")
            } catch {
                print("Unexpected error loading schedules: \(error)")
            }
        }
        
        // Update published property on main thread
        self.schedules = schedulesDict
        print("THREAD_LOG: YourViewModel.loadSchedules - END - Loaded schedules: \(schedules.count) entries. Is Main Thread: \(Thread.isMainThread), Current Thread: \(Thread.current)")
    }

    
    // MARK: - Load All Schedules
    func loadAllSchedules() async {
        print("Starting loadAllSchedules()")

        // 1. Collect results as NSManagedObjectID arrays from the TaskGroup
        // The TaskGroup will now return (DayOfWeek, [NSManagedObjectID])
        let islandObjectIDsTempDict = await withTaskGroup(of: (DayOfWeek, [NSManagedObjectID]).self) { group -> [DayOfWeek: [NSManagedObjectID]] in
            var result: [DayOfWeek: [NSManagedObjectID]] = [:]

            for day in DayOfWeek.allCases {
                group.addTask { [self] in // Capture self strongly for the async task
                    print("TaskGroup: Fetching island ObjectIDs for day: \(day.rawValue)")

                    do {
                        // This now correctly receives [NSManagedObjectID]
                        let fetchedObjectIDs = try await self.repository.fetchAllIslands(forDay: day.rawValue)
                        print("TaskGroup: Fetched \(fetchedObjectIDs.count) island ObjectIDs for day \(day.rawValue).")
                        return (day, fetchedObjectIDs)
                    } catch {
                        print("TaskGroup: Error fetching island ObjectIDs for day \(day.rawValue): \(error.localizedDescription)")
                        return (day, []) // Return an empty array of ObjectIDs on error
                    }
                }
            }

            // Await all tasks and collect their results
            for await (day, fetchedObjectIDsForDay) in group {
                result[day] = fetchedObjectIDsForDay
            }

            print("TaskGroup: Completed fetching all island ObjectIDs. Total days processed: \(result.count)")
            return result
        }

        // 2. Rehydrate the PirateIsland objects and extract MatTimes on the MainActor
        await MainActor.run {
            print("MainActor: Starting rehydration of islands and matTimes.")
            var hydratedSchedules: [DayOfWeek: [(PirateIsland, [MatTime])]] = [:]

            for (day, objectIDs) in islandObjectIDsTempDict {
                var islandsWithMatTimesForDay: [(PirateIsland, [MatTime])] = []
                for objectID in objectIDs {
                    do {
                        // Rehydrate the PirateIsland object on the main context
                        guard let island = try self.viewContext.existingObject(with: objectID) as? PirateIsland else {
                            print("    ❌ MainActor: Failed to rehydrate PirateIsland with ID: \(objectID)")
                            continue
                        }

                        // Now that 'island' is rehydrated on the MainActor, safely access its relationships and properties
                        guard let appDayOfWeeks = island.appDayOfWeeks as? Set<AppDayOfWeek> else {
                            print("    ⚠️ MainActor: Island \(island.islandName ?? "Unnamed") has no AppDayOfWeeks relationship.")
                            continue
                        }

                        let matTimesForCurrentDay: [MatTime] = appDayOfWeeks
                            .filter { $0.day.lowercased() == day.rawValue.lowercased() }
                            .compactMap { appDayOfWeek in
                                appDayOfWeek.matTimes?.allObjects as? [MatTime]
                            }
                            .flatMap { $0 } // flatten from [[MatTime]] → [MatTime]
                            .sorted { ($0.createdTimestamp ?? Date()) < ($1.createdTimestamp ?? Date()) }


                        if matTimesForCurrentDay.isEmpty {
                            print("    ⚠️ MainActor: Island \(island.islandName ?? "Unnamed") has no MatTimes for day \(day.rawValue). Excluding from schedule.")
                            continue // Exclude islands without mat times for this specific day
                        }

                        islandsWithMatTimesForDay.append((island, matTimesForCurrentDay))
                        let latString = String(format: "%.6f", island.latitude)
                        let lonString = String(format: "%.6f", island.longitude)
                        print("    ✅ MainActor: Rehydrated and processed Island: \(island.islandName ?? "Unnamed"), MatTimes: \(matTimesForCurrentDay.count), Lat: \(latString), Lon: \(lonString), ID: \(island.objectID)")

                    } catch {
                        print("    ❌ MainActor: Error rehydrating or processing island \(objectID): \(error.localizedDescription)")
                    }
                }
                // Only add the day to the dictionary if there are valid islands with mat times for it
                if !islandsWithMatTimesForDay.isEmpty {
                    hydratedSchedules[day] = islandsWithMatTimesForDay
                }
            }

            self.islandSchedules = hydratedSchedules
            print("✨ MainActor: Successfully updated islandSchedules with \(self.islandSchedules.count) days.")
        }
    }
    
    // MARK: - Fetch and Update List of AppDayOfWeek for a Specific Day
    func fetchAppDayOfWeekAndUpdateList(for island: PirateIsland, day: DayOfWeek, context: NSManagedObjectContext) {
        print("Fetching AppDayOfWeek for island: \(island.islandName ?? "Unknown") and day: \(day.displayName)")
        
        // Fetching the AppDayOfWeek entity
        if let appDayOfWeek = repository.fetchAppDayOfWeek(for: day.rawValue, pirateIsland: island, context: context) {
            print("Fetched AppDayOfWeek: \(appDayOfWeek)")
            
            // Fetch from Firestore
            firestore.collection("appDayOfWeek").document(day.rawValue).getDocument { document, error in
                if let error = error {
                    print("Failed to fetch AppDayOfWeek from Firestore: \(error.localizedDescription)")
                    return
                }
                
                if let document = document, let data = document.data() {
                    // Update AppDayOfWeek properties
                    appDayOfWeek.configure(data: data)
                }
            }
            
            // Check if matTimes is available and cast to [MatTime]
            if let matTimes = appDayOfWeek.matTimes?.allObjects as? [MatTime] {
                matTimesForDay[day] = matTimes
                print("Updated matTimesForDay for \(day.displayName): \(matTimesForDay[day] ?? [])")
            } else {
                print("No mat times found for \(day.displayName) on island \(island.islandName ?? "Unknown")")
            }
        } else {
            print("No AppDayOfWeek found for \(day.displayName) on island \(island.islandName ?? "Unknown")")
        }
        
        // Log the entire matTimesForDay dictionary after update
        print("Current matTimesForDay: \(matTimesForDay)")
    }
    
    // MARK: - Equatable Implementation
    static func == (lhs: AppDayOfWeekViewModel, rhs: AppDayOfWeekViewModel) -> Bool {
        lhs.selectedIsland == rhs.selectedIsland &&
        lhs.currentAppDayOfWeek == rhs.currentAppDayOfWeek &&
        lhs.matTime == rhs.matTime &&
        lhs.islandsWithMatTimes == rhs.islandsWithMatTimes &&
        lhs.islandSchedules == rhs.islandSchedules &&
        lhs.appDayOfWeekList == rhs.appDayOfWeekList &&
        lhs.appDayOfWeekID == rhs.appDayOfWeekID &&
        lhs.saveEnabled == rhs.saveEnabled &&
        lhs.schedules == rhs.schedules &&
        lhs.allIslands == rhs.allIslands &&
        lhs.errorMessage == rhs.errorMessage &&
        lhs.newMatTime == rhs.newMatTime &&
        lhs.dayOfWeekStates == rhs.dayOfWeekStates &&
        lhs.giForDay == rhs.giForDay &&
        lhs.noGiForDay == rhs.noGiForDay &&
        lhs.openMatForDay == rhs.openMatForDay &&
        lhs.restrictionsForDay == rhs.restrictionsForDay &&
        lhs.restrictionDescriptionForDay == rhs.restrictionDescriptionForDay &&
        lhs.goodForBeginnersForDay == rhs.goodForBeginnersForDay &&
        lhs.kidsForDay == rhs.kidsForDay &&
        lhs.matTimeForDay == rhs.matTimeForDay &&
        lhs.selectedTimeForDay == rhs.selectedTimeForDay &&
        lhs.matTimesForDay == rhs.matTimesForDay &&
        lhs.showError == rhs.showError &&
        lhs.selectedAppDayOfWeek == rhs.selectedAppDayOfWeek
    }
    
    // MARK: - Add New Mat Time
    func addNewMatTime() async {
        guard let day = selectedDay, let island = selectedIsland else {
            errorMessage = "Day of the week or gym is not selected."
            print("Error: Day of the week or gym is not selected.")
            return
        }
        
        let context = repository.getViewContext()
        guard let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(
            for: day.rawValue,
            pirateIsland: island,
            context: context
        ) else {
            print("Error fetching or creating appDayOfWeek")
            return
        }
        
        appDayOfWeek.day = day.rawValue
        appDayOfWeek.pIsland = island
        appDayOfWeek.name = "\(island.islandName ?? "Unknown Gym") \(day.displayName)"
        appDayOfWeek.createdTimestamp = Date()
        
        if let unwrappedMatTime = newMatTime {
            await addMatTime(matTime: unwrappedMatTime, for: day, appDayOfWeek: appDayOfWeek)
            
            // Add to Firestore
            firestore.collection("matTimes").addDocument(data: [
                "time": unwrappedMatTime.time ?? "",
                "type": unwrappedMatTime.type ?? "",
                "gi": unwrappedMatTime.gi,
                "noGi": unwrappedMatTime.noGi,
                "openMat": unwrappedMatTime.openMat,
                "restrictions": unwrappedMatTime.restrictions,
                "restrictionDescription": unwrappedMatTime.restrictionDescription ?? "",
                "goodForBeginners": unwrappedMatTime.goodForBeginners,
                "kids": unwrappedMatTime.kids,
                "appDayOfWeek": appDayOfWeek.appDayOfWeekID ?? ""
            ]) { error in
                if let error = error {
                    print("Failed to add MatTime to Firestore: \(error.localizedDescription)")
                }
            }
        } else {
            print("Error: newMatTime is unexpectedly nil")
        }
        
        await saveData()
        newMatTime = nil // Reset newMatTime to nil
    }
    
    
    // MARK: - Add Mat Time
    func addMatTime(matTime: MatTime, for day: DayOfWeek, appDayOfWeek: AppDayOfWeek) async {
        print("Adding MatTime: \(matTime) for day: \(day) and appDayOfWeek: \(appDayOfWeek)")
        
        // Create a new MatTime object
        let newMatTimeObject = MatTime(context: viewContext)
        newMatTimeObject.time = matTime.time
        newMatTimeObject.type = matTime.type
        // Set other MatTime fields as needed
        
        // Assign the AppDayOfWeek to the new MatTime object
        newMatTimeObject.appDayOfWeek = appDayOfWeek
        
        // Add the MatTime to the AppDayOfWeek
        appDayOfWeek.addToMatTimes(newMatTimeObject)
        
        // Save the context
        await saveData()
        
        // Add to Firestore
        firestore.collection("matTimes").addDocument(data: [
            "time": matTime.time ?? "",
            "type": matTime.type ?? "",
            "gi": matTime.gi,
            "noGi": matTime.noGi,
            "openMat": matTime.openMat,
            "restrictions": matTime.restrictions,
            "restrictionDescription": matTime.restrictionDescription ?? "",
            "goodForBeginners": matTime.goodForBeginners,
            "kids": matTime.kids,
            "appDayOfWeek": appDayOfWeek.appDayOfWeekID ?? ""
        ]) { error in
            if let error = error {
                print("Failed to add MatTime to Firestore: \(error.localizedDescription)")
            }
        }
        
        print("Added MatTime: \(newMatTimeObject)")
    }
    
    
    
    // MARK: - Update Bindings
    func updateBindings() {
        print("Updating bindings...")
        print("Selected Gym: \(selectedIsland?.islandName ?? "None")")
        print("Current AppDayOfWeek: \(currentAppDayOfWeek?.debugDescription ?? "None")")
        print("New MatTime: \(newMatTime?.debugDescription ?? "None")")
    }
    
    // MARK: - Validate Fields
    func validateFields() -> Bool {
        let isValid = !(name?.isEmpty ?? true) && !selectedType.isEmpty && selectedDay != nil
        let dayDescription = selectedDay != nil ? "\(selectedDay!)" : "nil"  // Adjust this based on how you want to display DayOfWeek
        print("Validation result: \(isValid). Name: \(name ?? "nil"), Selected Type: \(selectedType), Selected Day: \(dayDescription)")
        return isValid
    }
    
    // MARK: - Computed Property for Save Button Enabling
    var isSaveEnabled: Bool {
        let isEnabled = validateFields()
        print("Save button enabled: \(isEnabled)")
        return isEnabled
    }
    
    // MARK: - Handle User Interaction
    func handleUserInteraction() {
        guard let name = name, !name.isEmpty else {
            print("Error: Name is empty.")
            DispatchQueue.main.async {
                self.saveEnabled = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.saveEnabled = true
        }
        print("User interaction handled: Save enabled.")
    }
    // MARK: - Binding for Day Selection
    func binding(for day: DayOfWeek) -> Binding<Bool> {
        print("Creating binding for day: \(day.displayName)")
        
        let isSelected = self.isDaySelected(day)
        print("Current state for \(day.displayName): \(isSelected)")
        
        return Binding<Bool>(
            get: {
                self.isDaySelected(day)
            },
            set: { newValue in
                print("Updating state for \(day.displayName) to \(newValue)")
                self.setDaySelected(day, isSelected: newValue)
            }
        )
    }
    
    // MARK: - Methods from AppDayOfWeekRepository
    func setSelectedIsland(_ island: PirateIsland) {
        self.selectedIsland = island
        repository.setSelectedIsland(island)
        print("Selected gym set to: \(island)")
    }
    func setCurrentAppDayOfWeek(_ appDayOfWeek: AppDayOfWeek) {
        self.currentAppDayOfWeek = appDayOfWeek
        repository.setCurrentAppDayOfWeek(appDayOfWeek)
        print("Current AppDayOfWeek set to: \(appDayOfWeek)")
    }
    
    
    // MARK: - Add Mat Times For Day
    func addMatTimes(day: DayOfWeek, matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool,         restrictionDescription: String? , goodForBeginners: Bool, kids: Bool)]) async {
        print("Adding mat times: \(matTimes)")
        
        await withTaskGroup(of: Void.self) { group in
            matTimes.forEach { matTime in
                group.addTask { [self] in
                    print("Adding mat time: \(matTime)")
                    let newMatTime = MatTime(context: viewContext)
                    newMatTime.configure(
                        time: matTime.time,
                        type: matTime.type,
                        gi: matTime.gi,
                        noGi: matTime.noGi,
                        openMat: matTime.openMat,
                        restrictions: matTime.restrictions,
                        restrictionDescription: matTime.restrictionDescription,
                        goodForBeginners: matTime.goodForBeginners,
                        kids: matTime.kids
                    )
                    
                    // Async operation
                    let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: day.rawValue, pirateIsland: selectedIsland!, context: viewContext)
                    
                    if let appDayOfWeek = appDayOfWeek {
                        await addMatTime(matTime: newMatTime, for: day, appDayOfWeek: appDayOfWeek)
                    } else {
                        print("Failed to fetch or create AppDayOfWeek5")
                    }
                }
            }
        }
        
        print("Added \(matTimes.count) mat times for day: \(day)")
        await saveData()
    }
    
    // MARK: - GENERAL ADD MAT TIME
    func addMatTime(matTime: MatTime? = nil, for day: DayOfWeek) async {
        guard let island = selectedIsland else {
            errorMessage = "Selected gym is not set."
            print("Error2: Selected gym is not set.")
            return
        }
        
        print("Adding mat time for day: \(day)")
        
        // Fetch or create AppDayOfWeek
        let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: day.rawValue, pirateIsland: island, context: viewContext)
        
        if let appDayOfWeek = appDayOfWeek {
            currentAppDayOfWeek = appDayOfWeek
            
            if let matTime = matTime {
                guard matTime.time ?? "" != "" else {
                    print("Skipping empty MatTime object.")
                    return
                }
                
                if handleDuplicateMatTime(for: day, with: matTime) {
                    errorMessage = "MatTime already exists for this day."
                    print("Error: MatTime already exists for the selected day.")
                    return
                }
                
                matTime.appDayOfWeek = appDayOfWeek
                matTime.createdTimestamp = Date()
                
                // Add to Firestore
                firestore.collection("matTimes").addDocument(data: [
                    "time": matTime.time ?? "",
                    "type": matTime.type ?? "",
                    "gi": matTime.gi,
                    "noGi": matTime.noGi,
                    "openMat": matTime.openMat,
                    "restrictions": matTime.restrictions,
                    "restrictionDescription": matTime.restrictionDescription ?? "",
                    "goodForBeginners": matTime.goodForBeginners,
                    "kids": matTime.kids,
                    "appDayOfWeek": appDayOfWeek.appDayOfWeekID ?? ""
                ]) { error in
                    if let error = error {
                        print("Failed to add MatTime to Firestore: \(error.localizedDescription)")
                    }
                }
                
                await addMatTime(matTime: matTime, for: day, appDayOfWeek: appDayOfWeek)
                await saveData()
                await refreshMatTimes() // Added await here
                print("Mat times for day: \(day) - \(matTimesForDay[day] ?? []) FROM func addMatTime")
            }
        }
    }
    
    // MARK: - Remove MatTime
    func removeMatTime(_ matTime: MatTime) async throws {
        guard let matTimeID = matTime.id?.uuidString else {
            print("MatTime does not have a valid ID.")
            throw NSError(domain: "AppDayOfWeekViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid MatTime ID"])
        }

        do {
            // Delete from Firestore
            try await firestore.collection("matTimes").document(matTimeID).delete()

            // Delete from Core Data on main thread
            await MainActor.run {
                viewContext.delete(matTime)
            }

            await saveData()
        } catch {
            print("Failed to remove MatTime: \(error.localizedDescription)")
            throw error
        }
    }

    
    // MARK: - Clear Selections
    func clearSelections() {
        DayOfWeek.allCases.forEach { day in
            dayOfWeekStates[day] = false
            print("Cleared selection for day: \(day)")
        }
    }
    
    // MARK: - Toggle Day Selection
    func toggleDaySelection(_ day: DayOfWeek) {
        let currentState = dayOfWeekStates[day] ?? false
        dayOfWeekStates[day] = !currentState
        print("Toggled selection for day: \(day). New state: \(dayOfWeekStates[day] ?? false)")
    }
    
    // MARK: - Check if a Day is Selected
    func isSelected(_ day: DayOfWeek) -> Bool {
        let isSelected = dayOfWeekStates[day] ?? false
        print("Day: \(day) is selected: \(isSelected)")
        return isSelected
    }
    
    // MARK: - Update Schedules
    func updateSchedules() {
        guard let selectedIsland = self.selectedIsland else {
            print("Error3: Selected gym is not set. Selected Island: \(String(describing: self.selectedIsland))")
            return
        }
        
        guard let selectedDay = self.selectedDay else {
            print("Error: Selected day is not set.")
            return
        }
        
        print("Updating schedules for island: \(selectedIsland) and day: \(selectedDay)")
        
        // Fetch AppDayOfWeek from Firestore
        firestore.collection("appDayOfWeek").document(selectedDay.rawValue).getDocument { document, error in
            if let error = error {
                print("Failed to fetch AppDayOfWeek from Firestore: \(error.localizedDescription)")
                return
            }
            
            if let document = document, let data = document.data() {
                // Update AppDayOfWeek properties
                self.selectedAppDayOfWeek?.configure(data: data)
            }
        }
        
        // Update matTimesForDay dictionary
        self.matTimesForDay[selectedDay] = self.selectedAppDayOfWeek?.matTimes?.allObjects as? [MatTime] ?? []
        print("Updated mat times for day: \(selectedDay). Count: \(self.matTimesForDay[selectedDay]?.count ?? 0)")
    }
    
    // MARK: - Handle Duplicate Mat Time
    func handleDuplicateMatTime(for day: DayOfWeek, with matTime: MatTime) -> Bool {
        let existingMatTimes = matTimesForDay[day] ?? []
        let isDuplicate = existingMatTimes.contains { existingMatTime in
            existingMatTime.time == matTime.time && existingMatTime.type == matTime.type
        }
        print("Checking for duplicate MatTime for day: \(day). Is duplicate: \(isDuplicate)")
        return isDuplicate
    }
    
    // MARK: - Is Day Selected
    func isDaySelected(_ day: DayOfWeek) -> Bool {
        let isSelected = dayOfWeekStates[day] ?? false
        print("Day \(day.displayName) selected: \(isSelected)")
        return isSelected
    }
    
    // MARK: - Set Day Selected
    func setDaySelected(_ day: DayOfWeek, isSelected: Bool) {
        dayOfWeekStates[day] = isSelected
        print("Set day \(day.displayName) selected state to: \(isSelected)")
    }

    
    // Assuming this is inside your AppDayOfWeekViewModel class
    func fetchIslands(forDay day: DayOfWeek) async {
        print("🚀 AppDayOfWeekViewModel: Starting fetch for day: \(day.rawValue)")
        do {
            // 1. Fetch islands from Firestore for the day (background)
            let querySnapshot = try await firestore.collection("islands")
                .whereField("days", arrayContains: day.rawValue)
                .getDocuments()
            print("☁️ Firestore: Fetched \(querySnapshot.documents.count) documents for day \(day.rawValue).")
            
            // 2. Merge Firestore data into Core Data on background context
            let islandsToUpdateInFirestore = try await withCheckedThrowingContinuation { continuation in
                PersistenceController.shared.container.performBackgroundTask { backgroundContext in
                    do {
                        var firestoreUpdateList: [(PirateIsland, DocumentReference)] = []
                        
                        for document in querySnapshot.documents {
                            let islandID = document.data()["id"] as? String ?? document.documentID
                            let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                            fetchRequest.predicate = NSPredicate(format: "id == %@", islandID)
                            fetchRequest.fetchLimit = 1
                            
                            let existingIsland = try? backgroundContext.fetch(fetchRequest).first
                            if let island = existingIsland {
                                island.configure(document.data())
                                firestoreUpdateList.append((island, document.reference))
                                print("    ➡️ Updated existing island: \(island.islandName ?? "Unnamed")")
                            } else {
                                let newIsland = PirateIsland(context: backgroundContext)
                                newIsland.configure(document.data())
                                newIsland.islandID = UUID(uuidString: islandID) ?? UUID()
                                firestoreUpdateList.append((newIsland, document.reference))
                                print("    ➡️ Created new island: \(newIsland.islandName ?? "Unnamed")")
                            }
                        }
                        
                        if backgroundContext.hasChanges {
                            try backgroundContext.save()
                            print("    💾 BackgroundContext: Saved changes after Firestore merge.")
                        }
                        
                        continuation.resume(returning: firestoreUpdateList)
                    } catch {
                        print("    ❌ BackgroundContext: Error merging Firestore data: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            // 3. Fetch merged islands from Core Data on main thread for UI update
            let islandsWithMatTimes: [(PirateIsland, [MatTime])] = try await MainActor.run {
                let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "ANY appDayOfWeeks.day == %@", day.rawValue)

                let islands = try viewContext.fetch(fetchRequest)

                // Prepare array of islands with MatTime children filtered by day
                return islands.map { island in
                    // Filter appDayOfWeeks for the selected day
                    let filteredDays = (island.appDayOfWeeks?.compactMap { $0 as? AppDayOfWeek } ?? [])
                        .filter { $0.day == day.rawValue }

                    // Flatten all MatTime objects from these filtered AppDayOfWeek
                    let matTimes = filteredDays.flatMap { dayOfWeek in
                        (dayOfWeek.matTimes?.compactMap { $0 as? MatTime }) ?? []
                    }

                    return (island, matTimes)
                }
            }

            // 4. Update your published property on main thread
            await MainActor.run {
                self.islandsWithMatTimes = islandsWithMatTimes
                print("✨ Updated islandsWithMatTimes with \(islandsWithMatTimes.count) islands for day \(day.rawValue).")
            }
            
            // 5. Optionally update Firestore documents with any synced day info (if needed)
            for (island, ref) in islandsToUpdateInFirestore {
                let days = island.appDayOfWeeks?.compactMap { ($0 as? AppDayOfWeek)?.day } ?? []
                print("    ☁️ Firestore Update: Updating 'days' for \(island.islandName ?? "Unnamed") with \(days)")
                try await ref.updateData(["days": days])
            }
            
        } catch {
            print("❌ AppDayOfWeekViewModel: Error fetching islands: \(error.localizedDescription)")
            // Set error message for UI if needed
        }
    }

    
    func updateCurrentDayAndMatTimes(for island: PirateIsland, day: DayOfWeek) {
        // Fetch the current day of the week from Firestore
        firestore.collection("appDayOfWeek").document(day.rawValue).getDocument { document, error in
            if let error = error {
                print("Failed to fetch AppDayOfWeek from Firestore: \(error.localizedDescription)")
                return
            }
            
            if let document = document, let data = document.data() {
                // Update AppDayOfWeek properties
                self.currentAppDayOfWeek?.configure(data: data)
            }
            
            // Fetch mat times for the current day
            if let matTimes = self.currentAppDayOfWeek?.matTimes?.allObjects as? [MatTime] {
                self.matTimesForDay[day] = matTimes
            } else {
                self.matTimesForDay[day] = []
            }
        }
    }
}


extension PirateIsland {
    func configure(_ data: [String: Any]) {
        // Map Firestore document data to PirateIsland properties
        if let islandIDString = data["islandID"] as? String {
            self.islandID = UUID(uuidString: islandIDString) // Convert String to UUID
        }
        self.islandName = data["islandName"] as? String
        self.islandLocation = data["islandLocation"] as? String // Corrected to islandLocation
        self.country = data["country"] as? String  // Add other fields as needed

        // Map days (which should be a relationship to AppDayOfWeek) if needed
        if data["days"] is [String] {
            // Create AppDayOfWeek objects and assign them
            // You need to create and associate AppDayOfWeek objects for each day if necessary
        }
    }
}


extension AppDayOfWeek {
    func configure(data: [String: Any]) {
        // Map Firestore data to AppDayOfWeek properties
        if let dayValue = data["day"] as? String {
            self.day = dayValue
        }
        if let nameValue = data["name"] as? String {
            self.name = nameValue
        }
        if let createdTimestamp = data["createdTimestamp"] as? Date {
            self.createdTimestamp = createdTimestamp
        }
        
        // If 'matTimes' is part of the Firestore document, map it here
        if let matTimesData = data["matTimes"] as? [[String: Any]] {
            self.matTimes = NSSet(array: matTimesData.compactMap { matData in
                let matTime = MatTime(context: self.managedObjectContext!)
                matTime.configure(data: matData) // Assuming you have a configure method for MatTime
                return matTime
            })
        }
        
        // Add 'pIsland' mapping if needed
        if let pIslandData = data["pIsland"] as? [String: Any] {
            let pirateIsland = PirateIsland(context: self.managedObjectContext!)
            pirateIsland.configure(pIslandData) // Map PirateIsland data
            self.pIsland = pirateIsland
        }
    }
}




extension AppDayOfWeek {
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": self.appDayOfWeekID ?? "", // Directly use the string
            "day": self.day,
            "name": self.name ?? "",
            "createdTimestamp": self.createdTimestamp ?? Date(),
            "pIsland": self.pIsland?.toFirestoreData() ?? [:], // Ensure to include PirateIsland data
        ]
        
        // Add matTimes if needed
        if let matTimes = self.matTimes as? Set<MatTime> {
            let matTimesData = matTimes.map { $0.toFirestoreData() }
            data["matTimes"] = matTimesData
        }
        
        return data
    }
}


extension MatTime {
    // Configure from a Firestore-style dictionary
    func configure(data: [String: Any]) {
        self.time = data["time"] as? String
        self.type = data["type"] as? String
        self.gi = data["gi"] as? Bool ?? false
        self.noGi = data["noGi"] as? Bool ?? false
        self.openMat = data["openMat"] as? Bool ?? false
        self.restrictions = data["restrictions"] as? Bool ?? false
        self.restrictionDescription = data["restrictionDescription"] as? String ?? ""
        self.goodForBeginners = data["goodForBeginners"] as? Bool ?? false
        self.kids = data["kids"] as? Bool ?? false
        self.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        self.createdTimestamp = data["createdTimestamp"] as? Date ?? Date()
    }

    // Direct in-app configuration
    func configure(
        time: String? = nil,
        type: String? = nil,
        gi: Bool = false,
        noGi: Bool = false,
        openMat: Bool = false,
        restrictions: Bool = false,
        restrictionDescription: String? = "",
        goodForBeginners: Bool = false,
        kids: Bool = false
    ) {
        self.time = time
        self.type = type
        self.gi = gi
        self.noGi = noGi
        self.openMat = openMat
        self.restrictions = restrictions
        self.restrictionDescription = restrictionDescription
        self.goodForBeginners = goodForBeginners
        self.kids = kids
    }
}




private extension String {
    var isNilOrEmpty: Bool {
        return self.isEmpty || self == "nil"
    }
}



 
