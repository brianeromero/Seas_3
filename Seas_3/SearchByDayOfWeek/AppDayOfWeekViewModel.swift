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
    private let firestore = Firestore.firestore()
    
    var viewContext: NSManagedObjectContext
    private let dataManager: PirateIslandDataManager
    public var repository: AppDayOfWeekRepository
    
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
        
        repository.updateAppDayOfWeek(appDayOfWeek, with: island, dayOfWeek: dayOfWeek, context: viewContext)
    }
    
    func saveAppDayOfWeekToFirestore() {
        guard let island = selectedIsland,
              let appDayOfWeek = currentAppDayOfWeek,
              let dayOfWeek = selectedDay else {
            errorMessage = "Gym, AppDayOfWeek, or DayOfWeek is not selected."
            print("Gym, AppDayOfWeek, or DayOfWeek is not selected.")
            return
        }
        
        let data: [String: Any] = [
            "day": dayOfWeek.rawValue,
            "name": appDayOfWeek.name ?? "",
            "appDayOfWeekID": appDayOfWeek.appDayOfWeekID ?? "",
            "pIsland": island.islandID ?? "",
            "createdByUserId": "Unknown User",
            "createdTimestamp": Date(),
            "lastModifiedByUserId": "Unknown User",
            "lastModifiedTimestamp": Date()
        ]
        
        firestore.collection("appDayOfWeek").document(appDayOfWeek.appDayOfWeekID ?? "").setData(data) { error in
            if let error = error {
                print("Failed to save AppDayOfWeek to Firestore: \(error.localizedDescription)")
            } else {
                self.saveAppDayOfWeekLocally()
            }
        }
    }
    
    func saveAppDayOfWeek() {
        saveAppDayOfWeekToFirestore()
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
        print("Attempting to fetch current day of week for island: \(island.islandName ?? ""), day: \(day)")

        if let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: day, pirateIsland: island, context: repository.getViewContext()) {
            print("Successfully fetched or created AppDayOfWeek")
            
            selectedDayBinding.wrappedValue = day // ✅ Runs on the main thread

            // Refresh the context
            repository.getViewContext().refresh(appDayOfWeek, mergeChanges: true)
            
            // Verify MatTime instances have the correct appDayOfWeek relationship
            for matTime in appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? [] {
                if matTime.appDayOfWeek == nil {
                    print("MatTime \(matTime.time ?? "Unknown Time") has no appDayOfWeek relationship set. MatTime object: \(matTime)")
                } else {
                    print("MatTime \(matTime.time ?? "Unknown Time") has appDayOfWeek: \(matTime.appDayOfWeek?.day ?? "None")")
                }
            }

            // Fetch from Firestore
            do {
                let document = try await firestore.collection("appDayOfWeek").document(day.rawValue).getDocument()
                if let data = document.data() {
                    // Update AppDayOfWeek properties
                    appDayOfWeek.configure(day: data)  // ✅ This now runs on the main thread
                    print("Successfully fetched AppDayOfWeek from Firestore")
                } else {
                    print("Failed to fetch AppDayOfWeek from Firestore: No data found")
                }
            } catch {
                print("Failed to fetch AppDayOfWeek from Firestore: \(error.localizedDescription)")
            }

            return (appDayOfWeek, appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? [])
        } else {
            print("Failed to fetch or create AppDayOfWeek")
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
        restrictionDescription: String?,
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
        _ existingMatTime: MatTime?,
        time: String,
        type: String,
        gi: Bool,
        noGi: Bool,
        openMat: Bool,
        restrictions: Bool,
        restrictionDescription: String,
        goodForBeginners: Bool,
        kids: Bool,
        for appDayOfWeek: AppDayOfWeek
    ) async throws -> MatTime {
        print("Using updateOrCreateMatTime, updating/creating MatTime for AppDayOfWeek with day: \(appDayOfWeek.day)")

        // Set the name attribute of the AppDayOfWeek instance
        appDayOfWeek.name = appDayOfWeek.day

        let matTime = existingMatTime ?? MatTime(context: viewContext)
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

        if existingMatTime == nil {
            appDayOfWeek.addToMatTimes(matTime)
            print("Added new MatTime to AppDayOfWeek.")
        }

        if viewContext.hasChanges {
            do {
                // Fetch or create UserInfo entity
                let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
                let results = try viewContext.fetch(fetchRequest)
                if let userInfo = results.first {
                    userInfo.name = "John Doe" // Set the name attribute
                }
                
                try viewContext.save()
                print("Context saved successfully for MatTime.")
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("No changes detected in viewContext for MatTime.")
        }

        await refreshMatTimes()
        print("MatTimes refreshed.")

        return matTime
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
            print("Failed to fetch or create AppDayOfWeek2.")
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
        newMatTime = MatTime(context: viewContext)
    }
    
    // MARK: - Load Schedules
    @MainActor
    func loadSchedules(for island: PirateIsland) async {
        _ = NSPredicate(format: "pIsland == %@", island)
        let appDayOfWeeks = await repository.fetchSchedules(for: island)
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
        print("Loaded schedules: \(schedules)")
    }
    
    // MARK: - Load All Schedules
    func loadAllSchedules() async {
        // Create a local dictionary to collect the results
        let islandSchedulesDict = await withTaskGroup(of: (DayOfWeek, [(PirateIsland, [MatTime])]).self) { group -> [DayOfWeek: [(PirateIsland, [MatTime])]] in
            for day in DayOfWeek.allCases {
                group.addTask { [self] in
                    print("Fetching islands for day: \(day.rawValue)")
                    
                    do {
                        let islandSchedulesForDay = try await self.repository.fetchAllIslands(forDay: day.rawValue)
                            .map { island, matTimes in
                                print("Gym: \(island.islandName ?? ""), MatTimes: \(matTimes)")
                                return (island, matTimes)
                            }
                        print("Gym schedules for day: \(islandSchedulesForDay)")
                        return (day, islandSchedulesForDay)
                    } catch {
                        print("Error fetching Gym schedule for day \(day.rawValue): \(error.localizedDescription)")
                        return (day, []) // Return an empty array on error
                    }
                }
            }
            
            var result: [DayOfWeek: [(PirateIsland, [MatTime])]] = [:]
            for await (day, islandSchedulesForDay) in group {
                result[day] = islandSchedulesForDay
            }
            
            print("Loaded All Gym Schedules: \(result)")
            return result
        }
        
        // Ensure updates to islandSchedules are done on the main thread
        await MainActor.run {
            self.islandSchedules = islandSchedulesDict
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
                    appDayOfWeek.configure(day: data)
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
    func addMatTimes(day: DayOfWeek, matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, kids: Bool)]) async {
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
                        print("Failed to fetch or create AppDayOfWeek3")
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
    func removeMatTime(_ matTime: MatTime) async {
        print("Removing MatTime: \(matTime)")
        
        // Ensure that 'id' is unwrapped before using it in Firestore
        if let matTimeID = matTime.id?.uuidString {
            do {
                // Remove from Firestore
                try await firestore.collection("matTimes").document(matTimeID).delete()
                
                // Remove from Core Data
                viewContext.delete(matTime)
                await saveData()
            } catch {
                print("Failed to remove MatTime from Firestore: \(error.localizedDescription)")
            }
        } else {
            print("MatTime does not have a valid ID.")
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
                self.selectedAppDayOfWeek?.configure(day: data)
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
    
    func fetchIslands(forDay day: DayOfWeek) async {
        do {
            // Fetch islands from Core Data repository asynchronously
            let islands = try await repository.fetchAllIslands(forDay: day.rawValue)
            print("Fetched islands: \(islands)")

            // Fetch islands from Firestore asynchronously
            let querySnapshot = try await firestore.collection("islands")
                .whereField("days", arrayContains: day.rawValue)
                .getDocuments()

            let islandsFromFirestore = querySnapshot.documents.compactMap { document -> PirateIsland? in
                // Convert Firestore document to PirateIsland
                let island = PirateIsland(context: self.viewContext)
                island.configure(document.data())
                return island
            }

            // Filter islands with MatTimes
            let filteredIslandsWithMatTimes = islandsFromFirestore.compactMap { pirateIsland -> (PirateIsland, [MatTime])? in
                guard let appDayOfWeeks = pirateIsland.appDayOfWeeks else { return nil }

                let filteredMatTimes = appDayOfWeeks.compactMap { dayOfWeek -> [MatTime]? in
                    guard let dayOfWeek = dayOfWeek as? AppDayOfWeek else { return nil }
                    if dayOfWeek.day == day.rawValue {
                        return dayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
                    }
                    return nil
                }.flatMap { $0 } // Flatten the nested array

                // If there are MatTimes for this island, return the tuple
                if !filteredMatTimes.isEmpty {
                    return (pirateIsland, filteredMatTimes)
                }
                return nil
            }

            print("Filtered islands with MatTimes count: \(filteredIslandsWithMatTimes.count)")

            // Update islandsWithMatTimes on the main thread
            await MainActor.run {
                self.islandsWithMatTimes = filteredIslandsWithMatTimes
            }

            // Update islands in Firestore
            for document in querySnapshot.documents {
                if let island = islandsFromFirestore.first(where: { $0.islandID == document["islandID"] as? UUID }) {
                    // Get the days from the related AppDayOfWeek entities
                    let days = island.appDayOfWeeks?.compactMap { ($0 as? AppDayOfWeek)?.day } ?? []
                    // Update Firestore document with the days
                    try await document.reference.updateData(["days": days])
                }
            }
            
        } catch {
            print("Error fetching islands: \(error)")
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
                self.currentAppDayOfWeek?.configure(day: data)
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


// Assuming PirateIsland is a Core Data class or a model that you use for Firestore mapping

extension PirateIsland {
    func configure(_ data: [String: Any]) {
        // Map Firestore document data to PirateIsland properties
        if let islandIDString = data["islandID"] as? String {
            self.islandID = UUID(uuidString: islandIDString) // Convert String to UUID
        }
        self.islandName = data["islandName"] as? String
        // Add other properties here as needed
        // For example:
        // self.days = data["days"] as? [String] ?? []
    }
}



extension AppDayOfWeek {
    func configure(
        day: String? = nil,
        matTimes: [MatTime]? = nil
    ) {
        self.day = day!
        self.matTimes = NSSet(array: matTimes ?? [])
    }
}

extension AppDayOfWeek {
    func configure(day data: [String: Any]) {
        // Assuming your AppDayOfWeek has properties like 'day' and other fields you want to configure
        if let dayValue = data["day"] as? String {
            self.day = dayValue
        }
        // Map other data fields similarly
        // Example:
        // self.matTimes = data["matTimes"] as? [MatTime] ?? []
    }
}



extension MatTime {
    func reset() {
        self.time = ""
        self.type = ""
        self.gi = false
        self.noGi = false
        self.openMat = false
        self.restrictions = false
        self.restrictionDescription = ""
        self.goodForBeginners = false
        self.kids = false
    }
    
    func configure(
        time: String? = nil,
        type: String? = nil,
        gi: Bool = false,
        noGi: Bool = false,
        openMat: Bool = false,
        restrictions: Bool = false,
        restrictionDescription: String? = nil,
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



 
