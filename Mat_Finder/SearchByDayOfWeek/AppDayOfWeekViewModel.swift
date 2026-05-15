// AppDayOfWeekViewModel.swift
// Mat_Finder
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Foundation
import Combine
import CoreData
import MapKit
@preconcurrency import FirebaseFirestore

@MainActor
final class AppDayOfWeekViewModel: ObservableObject {
    
    // MARK: - Published Properties
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
    @Published var restrictionsForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionDescriptionForDay: [DayOfWeek: String] = [:]
    @Published var goodForBeginnersForDay: [DayOfWeek: Bool] = [:]
    @Published var kidsForDay: [DayOfWeek: Bool] = [:]
    @Published var matTimeForDay: [DayOfWeek: String] = [:]
    @Published var selectedTimeForDay: [DayOfWeek: Date] = [:]
    @Published var showError = false
    @Published var selectedAppDayOfWeek: AppDayOfWeek?
    
    @Published var matTimes: [MatTime] = []
    
    @Published var displayedMarkers: [CustomMapMarker] = []
    

    private let clusterBreakLatitudeDelta: Double = 0.15
    private let clusterRadiusMiles: Double = 10


    
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    @Published var isDataLoaded: Bool = false
    
    // MARK: - Property Observers
    @Published var name: String? {
        didSet { handleUserInteraction() }
    }
    
    @Published var selectedType: String = "" {
        didSet { handleUserInteraction() }
    }
    
    @Published var selectedDay: DayOfWeek? {
        didSet { handleUserInteraction() }
    }
    
    // MARK: - DateFormatter
    public let dateFormatter: DateFormatter = AppDateFormatter.twelveHour

    // MARK: - Initializer
    init(selectedIsland: PirateIsland? = nil,
         repository: AppDayOfWeekRepository,
         enterZipCodeViewModel: EnterZipCodeViewModel) {
        self.selectedIsland = selectedIsland
        self.repository = repository
        self.viewContext = repository.getViewContext()
        self.dataManager = PirateIslandDataManager(viewContext: self.viewContext)
        self.enterZipCodeViewModel = enterZipCodeViewModel
        
        Task { @MainActor in
            await fetchPirateIslands()
            initializeDaySettings()
        }
        
    }
    
    // MARK: - Snapshot
    struct Snapshot: Equatable {
        let selectedIsland: PirateIsland?
        let currentAppDayOfWeek: AppDayOfWeek?
        let matTime: MatTime?
        let islandsWithMatTimes: [(PirateIsland, [MatTime])]
        let islandSchedules: [DayOfWeek: [(PirateIsland, [MatTime])]]
        let appDayOfWeekList: [AppDayOfWeek]
        let appDayOfWeekID: String?
        let saveEnabled: Bool
        let schedules: [DayOfWeek: [AppDayOfWeek]]
        let allIslands: [PirateIsland]
        let errorMessage: String?
        let newMatTime: MatTime?
        let dayOfWeekStates: [DayOfWeek: Bool]
        let restrictionsForDay: [DayOfWeek: Bool]
        let restrictionDescriptionForDay: [DayOfWeek: String]
        let goodForBeginnersForDay: [DayOfWeek: Bool]
        let kidsForDay: [DayOfWeek: Bool]
        let matTimeForDay: [DayOfWeek: String]
        let selectedTimeForDay: [DayOfWeek: Date]
        let matTimesForDay: [DayOfWeek: [MatTime]]
        let showError: Bool
        let selectedAppDayOfWeek: AppDayOfWeek?
        
        static func == (lhs: Snapshot, rhs: Snapshot) -> Bool {
            
            func islandsEqual(_ a: [PirateIsland], _ b: [PirateIsland]) -> Bool {
                a.map(\.id) == b.map(\.id)
            }
            
            func islandTuplesEqual(_ a: [(PirateIsland, [MatTime])],
                                   _ b: [(PirateIsland, [MatTime])]) -> Bool {
                guard a.count == b.count else { return false }
                for (lhsTuple, rhsTuple) in zip(a, b) {
                    if lhsTuple.0.id != rhsTuple.0.id { return false }
                    if lhsTuple.1.map(\.id) != rhsTuple.1.map(\.id) { return false }
                }
                return true
            }
            
            func islandSchedulesEqual(_ a: [DayOfWeek: [(PirateIsland, [MatTime])]],
                                      _ b: [DayOfWeek: [(PirateIsland, [MatTime])]]) -> Bool {
                guard a.keys.sorted() == b.keys.sorted() else { return false }
                for key in a.keys {
                    if !islandTuplesEqual(a[key] ?? [], b[key] ?? []) { return false }
                }
                return true
            }
            
            return lhs.selectedIsland?.id == rhs.selectedIsland?.id &&
            lhs.currentAppDayOfWeek == rhs.currentAppDayOfWeek &&
            lhs.matTime?.id == rhs.matTime?.id &&
            islandTuplesEqual(lhs.islandsWithMatTimes, rhs.islandsWithMatTimes) &&
            islandSchedulesEqual(lhs.islandSchedules, rhs.islandSchedules) &&
            lhs.appDayOfWeekList == rhs.appDayOfWeekList &&
            lhs.appDayOfWeekID == rhs.appDayOfWeekID &&
            lhs.saveEnabled == rhs.saveEnabled &&
            lhs.schedules == rhs.schedules &&
            islandsEqual(lhs.allIslands, rhs.allIslands) &&
            lhs.errorMessage == rhs.errorMessage &&
            lhs.newMatTime?.id == rhs.newMatTime?.id &&
            lhs.dayOfWeekStates == rhs.dayOfWeekStates &&
            lhs.restrictionsForDay == rhs.restrictionsForDay &&
            lhs.restrictionDescriptionForDay == rhs.restrictionDescriptionForDay &&
            lhs.goodForBeginnersForDay == rhs.goodForBeginnersForDay &&
            lhs.kidsForDay == rhs.kidsForDay &&
            lhs.matTimeForDay == rhs.matTimeForDay &&
            lhs.selectedTimeForDay == rhs.selectedTimeForDay &&
            lhs.matTimesForDay.mapValues { $0.map(\.id) } ==
            rhs.matTimesForDay.mapValues { $0.map(\.id) } &&
            lhs.showError == rhs.showError &&
            lhs.selectedAppDayOfWeek == rhs.selectedAppDayOfWeek
        }
    }
    
    // MARK: - Snapshot Computed Property
    var snapshot: Snapshot {
        Snapshot(
            selectedIsland: selectedIsland,
            currentAppDayOfWeek: currentAppDayOfWeek,
            matTime: matTime,
            islandsWithMatTimes: islandsWithMatTimes,
            islandSchedules: islandSchedules,
            appDayOfWeekList: appDayOfWeekList,
            appDayOfWeekID: appDayOfWeekID,
            saveEnabled: saveEnabled,
            schedules: schedules,
            allIslands: allIslands,
            errorMessage: errorMessage,
            newMatTime: newMatTime,
            dayOfWeekStates: dayOfWeekStates,
            restrictionsForDay: restrictionsForDay,
            restrictionDescriptionForDay: restrictionDescriptionForDay,
            goodForBeginnersForDay: goodForBeginnersForDay,
            kidsForDay: kidsForDay,
            matTimeForDay: matTimeForDay,
            selectedTimeForDay: selectedTimeForDay,
            matTimesForDay: matTimesForDay,
            showError: showError,
            selectedAppDayOfWeek: selectedAppDayOfWeek
        )
    }
    
    
    
    
    // Method to fetch AppDayOfWeek later
    // Method to fetch AppDayOfWeek later
    func updateDayAndFetch(day: DayOfWeek) async {
        guard let island = selectedIsland else {
            print("Island is not set.")
            return
        }

        let (appDayOfWeek, matTimes) = await fetchCurrentDayOfWeek(
            for: island,
            day: day
        )

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
    
    func saveAppDayOfWeekToFirestore(
        selectedIslandID: NSManagedObjectID,
        selectedDay: DayOfWeek,
        appDayOfWeekObjectID: NSManagedObjectID
    ) async throws {
        let backgroundContext = PersistenceController.shared.newBackgroundContext()

        let payload: (docID: String, data: [String: Any]) = try await backgroundContext.perform {
            guard let appDayOfWeek = try backgroundContext.existingObject(with: appDayOfWeekObjectID) as? AppDayOfWeek else {
                throw NSError(
                    domain: "AppDayOfWeekViewModel",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate AppDayOfWeek in background context."]
                )
            }

            guard let island = try backgroundContext.existingObject(with: selectedIslandID) as? PirateIsland else {
                throw NSError(
                    domain: "AppDayOfWeekViewModel",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate selectedIsland in background context."]
                )
            }

            let islandKey = island.islandID ?? island.islandName ?? "unknown-island"
            let docID = "\(islandKey)-\(selectedDay.rawValue)"

            return (docID: docID, data: appDayOfWeek.toFirestoreData())
        }

        try await firestore
            .collection("AppDayOfWeek")
            .document(payload.docID)
            .setData(payload.data, merge: true)
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
    
    @MainActor
    func fetchPirateIslands() async {
        print("Fetching gyms...")
        isDataLoaded = false
        errorMessage = nil
        
        do {
            let pirateIslands = try await dataManager.fetchPirateIslandsAsync()
            allIslands = pirateIslands
            isDataLoaded = true
            print("Fetched Gyms: \(allIslands)")
        } catch {
            allIslands = []
            errorMessage = "Error fetching gyms: \(error.localizedDescription)"
            isDataLoaded = true
            print("Error fetching gyms: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - Ensure Initialization
    func ensureInitialization() async {
        guard let island = selectedIsland else {
            errorMessage = "Island is not selected."
            print("Error: Island is not selected.")
            return
        }
        
        guard let selectedDay = selectedDay else {
            errorMessage = "Day is not selected."
            print("Error: Day is not selected.")
            return
        }
        
        let (appDayOfWeek, matTimes) = await fetchCurrentDayOfWeek(
            for: island,
            day: selectedDay
        )
        
        if appDayOfWeek != nil && matTimes != nil {
            print("Current day of the week initialized.")
        } else {
            print("Failed to fetch current day of the week.")
        }
    }

    // MARK: - Fetch Current Day Of Week
    // Populates the matTimesForDay dictionary with the scheduled mat times for each day
    @MainActor
    func fetchCurrentDayOfWeek(
        for island: PirateIsland,
        day: DayOfWeek
    ) async -> (AppDayOfWeek?, [MatTime]?) {

        print("Fetching current day of week for island: \(island.islandName ?? ""), day: \(day)")

        let context = repository.getViewContext()

        // ✅ Core Data path
        if let existing = repository.fetchAppDayOfWeek(
            for: day.rawValue,
            pirateIsland: island,
            context: context
        ) {
            self.currentAppDayOfWeek = existing

            let matTimes = (existing.matTimes?.allObjects as? [MatTime] ?? [])
                .sorted(by: MatTime.scheduleSort)

            self.matTimesForDay[day] = matTimes

            return (existing, matTimes)
        }

        print("❌ Not found in Core Data. Checking Firestore...")

        let docID = appDayDocumentID(for: island, day: day)

        do {
            let document = try await firestore
                .collection("AppDayOfWeek")
                .document(docID)
                .getDocument()

            guard let data = document.data() else {
                print("❌ No Firestore document data found for \(docID)")
                return (nil, nil)
            }

            guard let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(
                for: day.rawValue,
                pirateIsland: island,
                context: context
            ) else {
                print("❌ Failed to fetch or create AppDayOfWeek locally")
                return (nil, nil)
            }

            appDayOfWeek.configure(data: data)

            if appDayOfWeek.day.isEmpty {
                appDayOfWeek.day = day.rawValue
            }

            if appDayOfWeek.pIsland == nil {
                appDayOfWeek.pIsland = island
            }

            if appDayOfWeek.pirateIslandID == nil || appDayOfWeek.pirateIslandID?.isEmpty == true {
                appDayOfWeek.pirateIslandID = island.islandID
            }

            if context.hasChanges {
                try context.save()
            }

            self.currentAppDayOfWeek = appDayOfWeek

            let matTimes = (appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? [])
                .sorted(by: MatTime.scheduleSort)

            self.matTimesForDay[day] = matTimes

            return (appDayOfWeek, matTimes)

        } catch {
            print("❌ Firestore error: \(error.localizedDescription)")
            return (nil, nil)
        }
    }
    // MARK: - Add or Update Mat Time
    func addOrUpdateMatTime(
        time: String,
        type: String,
        gi: Bool,
        noGi: Bool,
        openMat: Bool,
        restrictions: Bool,
        restrictionDescription: String? = "OOGA BOOOGA1",
        goodForBeginners: Bool,
        kids: Bool,
        womensOnly: Bool,   // ✅ ADD THIS
        for day: DayOfWeek
    ) async {

        guard selectedIsland != nil else {
            print("Error: Selected gym is not set. Please select a gym before adding a mat time.")
            return
        }

        await addMatTimes(
            day: day,
            matTimes: [
                (
                    time: time,
                    type: type,
                    gi: gi,
                    noGi: noGi,
                    openMat: openMat,
                    restrictions: restrictions,
                    restrictionDescription: restrictionDescription,
                    goodForBeginners: goodForBeginners,
                    kids: kids,
                    womensOnly: womensOnly   // ✅ PASS THROUGH
                )
            ]
        )

        print("Added/Updated MatTime")
    }
    
    // MARK: - Update Or Create MatTime
    func updateOrCreateMatTime(
        _ existingMatTimeID: NSManagedObjectID?,
        time: String,
        type: String,
        style: String?,
        customStyle: String?,
        discipline: String,
        restrictions: Bool,
        restrictionDescription: String,
        goodForBeginners: Bool,
        kids: Bool,
        womensOnly: Bool,
        for appDayOfWeekID: NSManagedObjectID
    ) async throws -> NSManagedObjectID {

        let context = PersistenceController.shared.newBackgroundContext()

        return try await context.perform {

            guard let appDayOfWeek =
                    try context.existingObject(with: appDayOfWeekID) as? AppDayOfWeek
            else {
                throw NSError(
                    domain: "CoreData",
                    code: 404,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                        "AppDayOfWeek not found"
                    ]
                )
            }

            let matTime: MatTime

            if let existingID = existingMatTimeID,
               let existing =
                    try? context.existingObject(with: existingID) as? MatTime {

                matTime = existing

            } else {

                matTime = MatTime(context: context)
                matTime.createdTimestamp = Date()
            }

            if matTime.id == nil {
                matTime.id = UUID()
            }

            // Protect legacy rows
            if matTime.createdTimestamp == nil {
                matTime.createdTimestamp = Date()
            }

            // Keep string ID mirror in sync
            matTime.appDayOfWeekID = appDayOfWeek.appDayOfWeekID

            // =====================================================
            // ✅ CLEAN + NORMALIZE RESTRICTION TEXT
            // =====================================================

            let cleanedRestriction = restrictionDescription
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // 👉 OPTION A: Preserve exact user input (recommended)
            let finalRestriction = cleanedRestriction

            // 👉 OPTION B (uncomment if you want auto-capitalization)
            // let finalRestriction = cleanedRestriction.capitalized

            // 👉 DEBUG (REMOVE LATER)
            print("🧪 Incoming restrictionDescription:", restrictionDescription)
            print("🧪 Cleaned restrictionDescription:", cleanedRestriction)
            print("🧪 Final restrictionDescription:", finalRestriction)

            // =====================================================

            matTime.configure(
                time: time,
                type: type,
                style: style,
                customStyle: customStyle,
                discipline: discipline,
                restrictions: restrictions,
                restrictionDescription: finalRestriction,
                goodForBeginners: goodForBeginners,
                kids: kids,
                womensOnly: womensOnly
            )

            matTime.appDayOfWeek = appDayOfWeek

            try context.save()

            return matTime.objectID
        }
    }
    
    // MARK: - Refresh MatTimes
    @MainActor
    func refreshMatTimes() async {
        print("Refreshing MatTimes")

        if let selectedIsland = selectedIsland,
           let unwrappedSelectedDay = selectedDay {

            let (appDayOfWeek, matTimes) = await fetchCurrentDayOfWeek(
                for: selectedIsland,
                day: unwrappedSelectedDay
            )

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

        let request: NSFetchRequest<MatTime> = MatTime.fetchRequest()

        request.predicate = NSPredicate(
            format: "appDayOfWeek.day ==[c] %@", day.rawValue
        )

        request.fetchBatchSize = 20

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \MatTime.time, ascending: true),
            NSSortDescriptor(keyPath: \MatTime.discipline, ascending: true),
            NSSortDescriptor(keyPath: \MatTime.style, ascending: true)
        ]

        return try viewContext.fetch(request)
    }

    @MainActor
    func updateMatTime(_ matTime: MatTime) async throws {

        // -----------------------------
        // Validate AppDayOfWeek
        // -----------------------------
        guard let appDayOfWeek = matTime.appDayOfWeek else {
            throw NSError(
                domain: "AppDayOfWeekViewModel",
                code: 4,
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "MatTime has no associated AppDayOfWeek."
                ]
            )
        }

        // Infer island if needed
        if selectedIsland == nil,
           let inferredIsland = appDayOfWeek.pIsland {

            self.selectedIsland = inferredIsland
        }

        guard let selectedIsland = self.selectedIsland else {
            throw NSError(
                domain: "AppDayOfWeekViewModel",
                code: 5,
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "Missing selectedIsland for Firestore sync."
                ]
            )
        }

        // -----------------------------
        // Convert time to 24-hour format
        // -----------------------------
        let time24Hour: String

        if let rawTime = matTime.time,
           let date = AppDateFormatter.stringToDate(rawTime) {

            time24Hour = AppDateFormatter.dateToString(date)

        } else {

            #if DEBUG
            assertionFailure(
                "⚠️ Invalid MatTime.time format: \(matTime.time ?? "nil")"
            )
            #else
            print(
                "⚠️ Invalid MatTime.time format: \(matTime.time ?? "nil")"
            )
            #endif

            time24Hour = AppDateFormatter.dateToString(Date())
        }

        // -----------------------------
        // 1️⃣ Update Core Data (Background)
        // -----------------------------
        let updatedMatTimeObjectID =
        try await updateOrCreateMatTime(
            matTime.objectID,
            time: time24Hour,
            type: matTime.type ?? "",
            style: matTime.style,
            customStyle: matTime.customStyle,
            discipline: Discipline(rawValue: matTime.discipline ?? "")?.rawValue ?? Discipline.bjjGi.rawValue,
            restrictions: matTime.restrictions,
            restrictionDescription:
                matTime.restrictionDescription ?? "",

            goodForBeginners: matTime.goodForBeginners,

            kids: matTime.kids,

            womensOnly: matTime.womensOnly,

            for: appDayOfWeek.objectID
        )

        // Refetch on MAIN CONTEXT
        let updatedMatTime =
        try viewContext.existingObject(
            with: updatedMatTimeObjectID
        ) as! MatTime

        // Ensure CoreData save
        if let context = updatedMatTime.managedObjectContext,
           context.hasChanges {

            try context.save()
        }

        // Update published property
        self.matTime = updatedMatTime

        print(
            "✅ Mat time updated locally (ObjectID): \(updatedMatTimeObjectID)"
        )

        // -----------------------------
        // 2️⃣ Update Firestore
        // -----------------------------
        guard let matTimeID =
                updatedMatTime.id?.uuidString
        else {

            throw NSError(
                domain: "AppDayOfWeekViewModel",
                code: 7,
                userInfo: [
                    NSLocalizedDescriptionKey:
                    "MatTime has no ID for Firestore."
                ]
            )
        }

        let matTimeRef =
        Firestore.firestore()
            .collection("MatTime")
            .document(matTimeID)

        var data: [String: Any] = [

            "time": time24Hour,
            "type": updatedMatTime.type ?? "",
            "discipline": updatedMatTime.discipline ?? Discipline.bjjGi.rawValue,
            "style": updatedMatTime.style ?? "",
            "customStyle": updatedMatTime.customStyle ?? "",
            "restrictions": updatedMatTime.restrictions,
            "restrictionDescription": updatedMatTime.restrictionDescription ?? "",

            "goodForBeginners": updatedMatTime.goodForBeginners,
            "kids": updatedMatTime.kids,
            "womensOnly": updatedMatTime.womensOnly,

            "appDayOfWeekID": appDayOfWeek.appDayOfWeekID ?? "",

            "lastModifiedTimestamp": Timestamp(date: Date())
        ]

        // Add createdTimestamp only if missing
        if updatedMatTime.createdTimestamp == nil {
            data["createdTimestamp"] = Timestamp(date: Date())
        }

        // Add relationship reference
        if let selectedDayForAppDayOfWeek = DayOfWeek(rawValue: appDayOfWeek.day) {
            let appDayDocID = appDayDocumentID(for: selectedIsland, day: selectedDayForAppDayOfWeek)
            data["appDayOfWeek"] = Firestore.firestore().document("AppDayOfWeek/\(appDayDocID)")
            data["appDayDocumentID"] = appDayDocID
        }

        try await matTimeRef.setData(
            data,
            merge: true
        )

        print(
            "✅ MatTime fields updated in Firestore: \(matTimeID)"
        )

        // -----------------------------
        // 3️⃣ Update AppDayOfWeek Firestore
        // -----------------------------
        guard let selectedDayForAppDayOfWeek =
            DayOfWeek(rawValue: appDayOfWeek.day)
        else { return }

        try await saveAppDayOfWeekToFirestore(

            selectedIslandID:
                selectedIsland.objectID,

            selectedDay:
                selectedDayForAppDayOfWeek,

            appDayOfWeekObjectID:
                appDayOfWeek.objectID
        )

        print(
            "✅ Firestore update successful via saveAppDayOfWeekToFirestore."
        )
    }
    
    // MARK: - Update Day
    func updateDay(for island: PirateIsland, dayOfWeek: DayOfWeek) async {
        print("Updating day settings for gym: \(island) and dayOfWeek: \(dayOfWeek)")

        guard let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(
            for: dayOfWeek.rawValue,
            pirateIsland: island,
            context: viewContext
        ) else {
            print("Failed to fetch or create AppDayOfWeek.")
            return
        }

        repository.updateAppDayOfWeek(
            appDayOfWeek,
            with: island,
            dayOfWeek: dayOfWeek,
            context: viewContext
        )

        do {
            let docID = appDayDocumentID(for: island, day: dayOfWeek)

            var payload: [String: Any] = [
                "id": appDayOfWeek.id?.uuidString ?? "",
                "day": dayOfWeek.rawValue,
                "name": appDayOfWeek.name ?? "",
                "appDayOfWeekID": appDayOfWeek.appDayOfWeekID ?? "",
                "pirateIslandID": island.islandID ?? ""
            ]

            if let islandData = island.toFirestoreData() {
                payload["pIsland"] = islandData
            }

            try await firestore
                .collection("AppDayOfWeek")
                .document(docID)
                .setData(payload, merge: true)

        } catch {
            print("Failed to update AppDayOfWeek in Firestore: \(error.localizedDescription)")
        }

        await saveData()
        await refreshMatTimes()
    }
    // MARK: - Initialize Day Settings
    func initializeDaySettings() {
        print("Initializing day settings")
        let allDays: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        for day in allDays {
            dayOfWeekStates[day] = false
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
        self.newMatTime = MatTime(context: self.viewContext)
    }


    // MARK: - Load Schedules

    @MainActor
    func loadSchedules(for island: PirateIsland) async -> Bool {

        guard let day = selectedDay else { return false }

        print("LOAD_SCHEDULES: START for island: \(island.islandName ?? "Unknown") and day: \(day.displayName)")

        guard let appDayOfWeeks = island.appDayOfWeeks as? Set<AppDayOfWeek> else {
            matTimesForDay[day] = []
            schedules[day] = []
            return false
        }

        let dayAppDayOfWeeks =
            appDayOfWeeks.filter {
                $0.day.lowercased() == day.rawValue.lowercased()
            }

        let matTimes: [MatTime] =
            dayAppDayOfWeeks
            .compactMap { $0.matTimes?.allObjects as? [MatTime] }
            .flatMap { $0 }
            .sorted(by: MatTime.scheduleSort)

        matTimesForDay[day] = matTimes

        schedules[day] =
            Array(dayAppDayOfWeeks)
            .sorted {
                ($0.createdTimestamp ?? Date()) < ($1.createdTimestamp ?? Date())
            }

        print("Loaded \(matTimes.count) mat times for \(day.displayName) at \(island.islandName ?? "Unknown")")

        return !matTimes.isEmpty
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
                            .sorted(by: MatTime.scheduleSort)

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
    private func appDayDocumentID(for island: PirateIsland, day: DayOfWeek) -> String {
        let islandKey = island.islandID ?? island.islandName ?? "unknown-island"
        return "\(islandKey)-\(day.rawValue)"
    }

    func fetchAppDayOfWeekAndUpdateList(
        for island: PirateIsland,
        day: DayOfWeek,
        context: NSManagedObjectContext
    ) {
        print("Fetching AppDayOfWeek for island: \(island.islandName ?? "Unknown") and day: \(day.displayName)")

        guard let appDayOfWeek = repository.fetchAppDayOfWeek(
            for: day.rawValue,
            pirateIsland: island,
            context: context
        ) else {
            print("No AppDayOfWeek found for \(day.displayName) on island \(island.islandName ?? "Unknown")")
            return
        }

        let objectID = appDayOfWeek.objectID
        let docID = appDayDocumentID(for: island, day: day)

        firestore
            .collection("AppDayOfWeek")
            .document(docID)
            .getDocument { [weak self] document, error in
                guard let self else { return }

                if let error = error {
                    print("Failed to fetch AppDayOfWeek from Firestore: \(error.localizedDescription)")
                    return
                }

                guard let data = document?.data() else {
                    print("No Firestore data found for document: \(docID)")
                    return
                }

                context.perform {
                    do {
                        guard let appDayOfWeekInContext = try context.existingObject(with: objectID) as? AppDayOfWeek else {
                            print("Failed to rehydrate AppDayOfWeek for objectID: \(objectID)")
                            return
                        }

                        appDayOfWeekInContext.configure(data: data)

                        if context.hasChanges {
                            try context.save()
                        }

                        let matTimes = (appDayOfWeekInContext.matTimes?.allObjects as? [MatTime] ?? [])
                            .sorted(by: MatTime.scheduleSort)

                        Task { @MainActor in
                            self.matTimesForDay[day] = matTimes
                            print("Updated matTimesForDay for \(day.displayName): \(matTimes)")
                        }

                    } catch {
                        print("Failed updating AppDayOfWeek in context: \(error.localizedDescription)")
                    }
                }
            }
    }

    // MARK: - Add New Mat Time
    func addNewMatTime() async {

        guard let day = selectedDay,
              let island = selectedIsland else {

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
            print("Error fetching or creating AppDayOfWeek")
            return
        }

        appDayOfWeek.day = day.rawValue
        appDayOfWeek.pIsland = island
        appDayOfWeek.name = "\(island.islandName ?? "Unknown Gym") \(day.displayName)"
        appDayOfWeek.createdTimestamp = Date()

        guard let unwrappedMatTime = newMatTime else {
            print("Error: newMatTime is unexpectedly nil")
            return
        }

        await addMatTime(matTime: unwrappedMatTime, for: day, appDayOfWeek: appDayOfWeek)

        await saveData()

        newMatTime = nil
    }
    
    // MARK: - Add Mat Time (Core Data Only)
    func addMatTime(
        matTime: MatTime,
        for day: DayOfWeek,
        appDayOfWeek: AppDayOfWeek
    ) async {

        print("Adding MatTime: \(matTime) for day: \(day) and appDayOfWeek: \(appDayOfWeek)")

        // 1️⃣ Create new Core Data object
        let newMatTimeObject = MatTime(context: viewContext)

        // 2️⃣ Configure values
        newMatTimeObject.configure(
            time: matTime.time,
            type: matTime.type,
            style: matTime.style,
            customStyle: matTime.customStyle,
            discipline: matTime.discipline,
            restrictions: matTime.restrictions,
            restrictionDescription: matTime.restrictionDescription,
            goodForBeginners: matTime.goodForBeginners,
            kids: matTime.kids,
            womensOnly: matTime.womensOnly
        )

        // 3️⃣ Ensure identifiers
        if newMatTimeObject.id == nil {
            newMatTimeObject.id = UUID()
        }

        newMatTimeObject.createdTimestamp = Date()

        // 4️⃣ Attach relationships
        newMatTimeObject.appDayOfWeek = appDayOfWeek
        newMatTimeObject.appDayOfWeekID = appDayOfWeek.appDayOfWeekID

        appDayOfWeek.addToMatTimes(newMatTimeObject)

        // 5️⃣ Save Core Data
        await saveData()

        print("✅ MatTime added locally: \(newMatTimeObject)")
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
        self.saveEnabled = validateFields()
        print("User interaction handled: Save enabled = \(self.saveEnabled)")
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
    @MainActor
    func addMatTimes(
        day: DayOfWeek,
        matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool,
                    restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, kids: Bool, womensOnly: Bool)]
    ) async {

        guard let island = selectedIsland else { return }

        print("Adding \(matTimes.count) mat times for day: \(day)")

        // Prepare all MatTime objects first
        let newMatTimes: [MatTime] = matTimes.map { mat in
            let matTime = MatTime(context: viewContext)

            let discipline =
                mat.openMat ? Discipline.openMat.rawValue :
                mat.noGi ? Discipline.bjjNoGi.rawValue :
                Discipline.bjjGi.rawValue

            matTime.configure(
                time: mat.time,
                type: mat.type,
                style: nil,
                customStyle: nil,
                discipline: discipline,
                restrictions: mat.restrictions,
                restrictionDescription: mat.restrictionDescription,
                goodForBeginners: mat.goodForBeginners,
                kids: mat.kids,
                womensOnly: mat.womensOnly
            )

            return matTime
        }

        // Fetch or create AppDayOfWeek once
        guard let appDay = repository.fetchOrCreateAppDayOfWeek(
            for: day.rawValue,
            pirateIsland: island,
            context: viewContext
        ) else {
            print("Failed to fetch or create AppDayOfWeek")
            return
        }

        // Add all MatTime objects without saving each time
        for matTime in newMatTimes {
            await addMatTimeWithoutSaving(matTime: matTime, for: day, appDayOfWeek: appDay)
        }

        // Update UI
        let updatedMatTimes = (appDay.matTimes?.allObjects as? [MatTime] ?? [])
            .sorted(by: MatTime.scheduleSort)

        matTimesForDay[day] = updatedMatTimes

        // Save once at the end
        await saveData()

        print("Finished adding mat times for day: \(day)")
    }
    
    // MARK: - Add Mat Time (Core Data Only, No Save)
    func addMatTimeWithoutSaving(
        matTime: MatTime,
        for day: DayOfWeek,
        appDayOfWeek: AppDayOfWeek
    ) async {

        print("Adding MatTime without immediate save: \(matTime) for day: \(day) and appDayOfWeek: \(appDayOfWeek)")

        let newMatTimeObject = MatTime(context: viewContext)

        newMatTimeObject.configure(
            time: matTime.time,
            type: matTime.type,
            style: matTime.style,
            customStyle: matTime.customStyle,
            discipline: matTime.discipline,
            restrictions: matTime.restrictions,
            restrictionDescription: matTime.restrictionDescription,
            goodForBeginners: matTime.goodForBeginners,
            kids: matTime.kids,
            womensOnly: matTime.womensOnly
        )

        if newMatTimeObject.id == nil {
            newMatTimeObject.id = UUID()
        }

        newMatTimeObject.createdTimestamp = Date()
        newMatTimeObject.appDayOfWeek = appDayOfWeek
        newMatTimeObject.appDayOfWeekID = appDayOfWeek.appDayOfWeekID

        appDayOfWeek.addToMatTimes(newMatTimeObject)

        print("✅ MatTime staged locally: \(newMatTimeObject)")
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
        guard let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(
            for: day.rawValue,
            pirateIsland: island,
            context: viewContext
        ) else {
            print("Failed to fetch or create AppDayOfWeek")
            return
        }

        currentAppDayOfWeek = appDayOfWeek

        guard let matTime = matTime else { return }

        guard matTime.time?.isEmpty == false else {
            print("Skipping empty MatTime object.")
            return
        }

        if handleDuplicateMatTime(for: day, with: matTime) {
            errorMessage = "MatTime already exists for this day."
            print("Error: MatTime already exists for the selected day.")
            return
        }

        // Attach relationship
        matTime.appDayOfWeek = appDayOfWeek
        matTime.appDayOfWeekID = appDayOfWeek.appDayOfWeekID
        matTime.createdTimestamp = Date()

        // Build Firestore data using the helper
        var data = matTime.toFirestoreData()
        data["appDayOfWeekID"] = appDayOfWeek.appDayOfWeekID ?? ""
        data["appDayDocumentID"] = appDayDocumentID(for: island, day: day)

        // Add relationship reference
        let appDayDocID = appDayDocumentID(for: island, day: day)
        data["appDayOfWeek"] = Firestore.firestore().document("AppDayOfWeek/\(appDayDocID)")
        
        // Firestore write
        
        if matTime.id == nil {
            matTime.id = UUID()
        }
        
        guard let id = matTime.id?.uuidString else { return }

        do {
            try await firestore
                .collection("MatTime")
                .document(id)
                .setData(data)

            print("✅ MatTime added to Firestore")

        } catch {
            print("❌ Failed to add MatTime to Firestore: \(error.localizedDescription)")
        }

        // Add to Core Data relationship
        await addMatTime(matTime: matTime, for: day, appDayOfWeek: appDayOfWeek)

        await refreshMatTimes()

        print("Mat times for day: \(day) - \(matTimesForDay[day] ?? []) FROM func addMatTime")
    }
    
    // MARK: - Remove MatTime
    func removeMatTime(_ matTime: MatTime) async throws {
        guard let matTimeID = matTime.id else {
            throw NSError(
                domain: "AppDayOfWeekViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid MatTime ID"]
            )
        }

        let rawID = matTimeID.uuidString                  // with hyphens
        let normalizedID = rawID.replacingOccurrences(of: "-", with: "") // without hyphens

        do {
            let collection = firestore.collection("MatTime")

            // 🔥 Delete BOTH possible Firestore document IDs (safe + idempotent)
            print("🗑 Deleting Firestore MatTime (normalized): \(normalizedID)")
            try await collection.document(normalizedID).delete()

            print("🗑 Deleting Firestore MatTime (legacy): \(rawID)")
            try await collection.document(rawID).delete()

            print("✅ Firestore delete(s) completed")

            // 🧠 Core Data delete on main actor
            await MainActor.run {
                viewContext.delete(matTime)
            }

            await saveData()
            print("✅ Deleted MatTime from Core Data")

        } catch {
            print("❌ Failed to remove MatTime: \(error.localizedDescription)")
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
    @MainActor
    func updateSchedules() async {
        guard let selectedIsland = self.selectedIsland else { return }
        guard let selectedDay = self.selectedDay else { return }

        print("Updating schedules for island: \(selectedIsland) and day: \(selectedDay)")

        do {
            let docID = appDayDocumentID(for: selectedIsland, day: selectedDay)

            let document = try await firestore
                .collection("AppDayOfWeek")
                .document(docID)
                .getDocument()

            guard let data = document.data() else {
                self.currentAppDayOfWeek = nil
                self.selectedAppDayOfWeek = nil
                self.matTimesForDay[selectedDay] = []
                return
            }

            guard let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(
                for: selectedDay.rawValue,
                pirateIsland: selectedIsland,
                context: viewContext
            ) else {
                print("Failed to fetch or create AppDayOfWeek for updateSchedules.")
                self.currentAppDayOfWeek = nil
                self.selectedAppDayOfWeek = nil
                self.matTimesForDay[selectedDay] = []
                return
            }

            appDayOfWeek.configure(data: data)
            currentAppDayOfWeek = appDayOfWeek
            selectedAppDayOfWeek = appDayOfWeek

            let matTimes = (appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? [])
                .sorted(by: MatTime.scheduleSort)

            self.matTimesForDay[selectedDay] = matTimes

            print("Updated mat times for day: \(selectedDay). Count: \(matTimes.count)")
        } catch {
            print("Failed to fetch AppDayOfWeek from Firestore: \(error.localizedDescription)")
        }
    }

    
    // MARK: - Handle Duplicate Mat Time
    func handleDuplicateMatTime(for day: DayOfWeek, with matTime: MatTime) -> Bool {
        let existingMatTimes = matTimesForDay[day] ?? []
        let isDuplicate = existingMatTimes.contains { existingMatTime in
            existingMatTime.time == matTime.time &&
            existingMatTime.discipline == matTime.discipline &&
            existingMatTime.style == matTime.style &&
            existingMatTime.kids == matTime.kids &&
            existingMatTime.womensOnly == matTime.womensOnly
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
    // Inside AppDayOfWeekViewModel
    func fetchIslands(forDay day: DayOfWeek) async {
        print("🚀 AppDayOfWeekViewModel: Starting fetch for day: \(day.rawValue)")

        do {
            // 1️⃣ Fetch islands from Firestore for the day (background)
            let querySnapshot = try await firestore.collection("islands")
                .whereField("days", arrayContains: day.rawValue)
                .getDocuments()
            print("☁️ Firestore: Fetched \(querySnapshot.documents.count) documents for day \(day.rawValue).")

            // 2️⃣ Merge Firestore data into Core Data on a background context
            let islandsToUpdateInFirestore = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(PirateIsland, DocumentReference)], Error>) in
                PersistenceController.shared.container.performBackgroundTask { backgroundContext in
                    do {
                        var firestoreUpdateList: [(PirateIsland, DocumentReference)] = []

                        for document in querySnapshot.documents {
                            let islandID = document.data()["id"] as? String ?? document.documentID
                            let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
                            fetchRequest.predicate = NSPredicate(format: "islandID == %@", islandID)
                            fetchRequest.fetchLimit = 1

                            let existingIsland = try? backgroundContext.fetch(fetchRequest).first
                            if let island = existingIsland {
                                island.configure(document.data())
                                firestoreUpdateList.append((island, document.reference))
                            } else {
                                let newIsland = PirateIsland(context: backgroundContext)
                                newIsland.configure(document.data())
                                newIsland.islandID = islandID.isEmpty ? UUID().uuidString : islandID
                                firestoreUpdateList.append((newIsland, document.reference))
                            }
                        }

                        if backgroundContext.hasChanges {
                            try backgroundContext.save()
                        }

                        continuation.resume(returning: firestoreUpdateList)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            // 3️⃣ Fetch merged islands from Core Data on the main actor (UI-safe)
            await MainActor.run {

                do {

                    let fetchRequest: NSFetchRequest<PirateIsland> =
                    PirateIsland.fetchRequest()

                    fetchRequest.predicate =
                    NSPredicate(format: "ANY appDayOfWeeks.day == %@", day.rawValue)

                    let islands = try viewContext.fetch(fetchRequest)

                    let islandsWithMatTimes =
                    islands.compactMap { island -> (PirateIsland, [MatTime])? in

                        let filteredDays =
                        (island.appDayOfWeeks?.compactMap { $0 as? AppDayOfWeek } ?? [])
                            .filter { $0.day == day.rawValue }

                        let matTimes =
                        filteredDays.flatMap {
                            ($0.matTimes?.compactMap { $0 as? MatTime }) ?? []
                        }

                        guard !matTimes.isEmpty else { return nil }

                        return (island, matTimes)
                    }

                    self.islandsWithMatTimes = islandsWithMatTimes

                    print("✅ CoreData fetch success: \(islandsWithMatTimes.count)")

                } catch {

                    print("❌ CoreData fetch failed:", error)

                    self.islandsWithMatTimes = []
                }
            }

            // 4️⃣ Optionally update Firestore documents with any synced day info
            for (backgroundIsland, ref) in islandsToUpdateInFirestore {

                let islandID = backgroundIsland.objectID

                let mainIsland =
                    viewContext.object(with: islandID) as? PirateIsland

                let days =
                    mainIsland?.appDayOfWeeks?.compactMap {
                        ($0 as? AppDayOfWeek)?.day
                    } ?? []

                print(
                    "☁️ Firestore Update: Updating 'days' for \(mainIsland?.islandName ?? "Unnamed") with \(days)"
                )

                try await ref.updateData(["days": days])
            }

        } catch {
            print("❌ AppDayOfWeekViewModel: Error fetching islands: \(error.localizedDescription)")
            // Optionally update UI with error message
        }
    }


    @MainActor
    func updateCurrentDayAndMatTimes(for island: PirateIsland, day: DayOfWeek) async {
        do {
            let docID = appDayDocumentID(for: island, day: day)

            let document = try await firestore
                .collection("AppDayOfWeek")
                .document(docID)
                .getDocument()

            guard let data = document.data() else {
                self.currentAppDayOfWeek = nil
                self.matTimesForDay[day] = []
                return
            }

            guard let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(
                for: day.rawValue,
                pirateIsland: island,
                context: viewContext
            ) else {
                self.currentAppDayOfWeek = nil
                self.matTimesForDay[day] = []
                return
            }

            appDayOfWeek.configure(data: data)
            self.currentAppDayOfWeek = appDayOfWeek

            let matTimes = (appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? [])
                .sorted(by: MatTime.scheduleSort)

            self.matTimesForDay[day] = matTimes
        } catch {
            print("Failed to fetch AppDayOfWeek from Firestore: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func clearSchedule() {

        matTimesForDay.removeAll()

    }
    
    // MARK: - Unified Schedule Preloader (Production-grade)
    func preloadAllSchedules(for island: PirateIsland) async {

        await MainActor.run {
            self.clearSchedule()
        }

        for day in DayOfWeek.allCases {
            let (_, matTimes) = await fetchCurrentDayOfWeek(
                for: island,
                day: day
            )

            if let matTimes {
                await MainActor.run {
                    self.matTimesForDay[day] = matTimes
                }
            }
        }

        // ✅ ALWAYS determine best day
        await MainActor.run {
            self.selectedDay = self.determineBestDefaultDay()
        }
    }
    
    func determineBestDefaultDay() -> DayOfWeek? {
        let now = Date()
        let today = DayOfWeek.today

        // 1️⃣ Today with future classes
        if let todayClasses = matTimesForDay[today],
           todayClasses.contains(where: {
               guard let time = $0.time,
                     let nextDate = MatTime.nextDate(for: today, time: time)
               else { return false }

               return nextDate > now
           }) {
            return today
        }

        // 2️⃣ Next available day
        let orderedDays = DayOfWeek.allCases.circularShifted(startingFrom: today)

        for day in orderedDays {
            if let classes = matTimesForDay[day], !classes.isEmpty {
                return day
            }
        }

        // 3️⃣ Fallback
        return .monday
    }
    
}


extension AppDayOfWeek {
    func configure(data: [String: Any]) {
        if let dayValue = data["day"] as? String {
            self.day = dayValue
        }

        if let nameValue = data["name"] as? String {
            self.name = nameValue
        }

        if let appDayOfWeekIDValue = data["appDayOfWeekID"] as? String {
            self.appDayOfWeekID = appDayOfWeekIDValue
        }

        if let pirateIslandIDValue = data["pirateIslandID"] as? String {
            self.pirateIslandID = pirateIslandIDValue
        }

        if let uuidString = data["id"] as? String {
            self.id = UUID(uuidString: uuidString)
        }

        if let timestamp = data["createdTimestamp"] as? Timestamp {
            self.createdTimestamp = timestamp.dateValue()
        } else if let date = data["createdTimestamp"] as? Date {
            self.createdTimestamp = date
        }

        guard let context = self.managedObjectContext else { return }

        if let matTimesData = data["matTimes"] as? [[String: Any]] {
            let existingMatTimes = (self.matTimes?.allObjects as? [MatTime]) ?? []

            let existingByID: [String: MatTime] = Dictionary(
                uniqueKeysWithValues: existingMatTimes.compactMap { matTime -> (String, MatTime)? in
                    guard let id = matTime.id?.uuidString else { return nil }
                    return (id, matTime)
                }
            )

            var updatedMatTimes: [MatTime] = []

            for matData in matTimesData {
                let matIDString = matData["id"] as? String
                let matTime = matIDString.flatMap { existingByID[$0] } ?? MatTime(context: context)

                matTime.configure(data: matData)
                matTime.appDayOfWeek = self
                matTime.appDayOfWeekID = self.appDayOfWeekID
                updatedMatTimes.append(matTime)
            }

            self.matTimes = NSSet(array: updatedMatTimes)
        }

        if self.pIsland == nil,
           let pirateIslandID = self.pirateIslandID,
           let island = fetchPirateIsland(with: pirateIslandID, in: context) {
            self.pIsland = island
        }
    }

    private func fetchPirateIsland(with islandID: String, in context: NSManagedObjectContext) -> PirateIsland? {
        let request: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        request.predicate = NSPredicate(format: "islandID == %@", islandID)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
}


extension AppDayOfWeek {

    func toFirestoreData() -> [String: Any] {

        var data: [String: Any] = [
            "id": self.id?.uuidString ?? "",
            "appDayOfWeekID": self.appDayOfWeekID ?? "",
            "day": self.day,
            "name": self.name ?? "",
            "createdTimestamp": self.createdTimestamp ?? Date(),
            "pirateIslandID": self.pirateIslandID ?? self.pIsland?.islandID ?? "",
            "pIsland": self.pIsland?.toFirestoreData() ?? [:]
        ]

        if let matTimes = self.matTimes as? Set<MatTime> {
            data["matTimes"] = matTimes.map { $0.toFirestoreData() }
        }

        return data
    }
}


private extension String {
    var isNilOrEmpty: Bool {
        return self.isEmpty || self == "nil"
    }
}


// MARK: - Equatable Conformance (identity-based, nonisolated)
extension AppDayOfWeekViewModel: Equatable {
    nonisolated static func == (lhs: AppDayOfWeekViewModel, rhs: AppDayOfWeekViewModel) -> Bool {
        // Identity-based equality: true only if both references point to the same instance.
        return lhs === rhs
    }
}
