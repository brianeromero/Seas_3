// AppDayOfWeekViewModel.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Foundation
import Combine
import CoreData

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
    func updateDayAndFetch(day: DayOfWeek) {
        guard let island = selectedIsland else {
            print("Island is not set.")
            return
        }
        
        // Fetch and assign the current day of the week
        if let _ = fetchCurrentDayOfWeek(for: island, day: day, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 })) {
            print("Updated day and fetched MatTimes.")
        } else {
            print("Failed to update day and fetch MatTimes.")
        }
    }

    // MARK: - Methods
    // MARK: - Save Data
    
    func saveData() {
        print("Saving data...")
        do {
            try PersistenceController.shared.saveContext()  // Use the shared PersistenceController
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }
    }
    
    
    
    func saveAppDayOfWeek() {
        guard let island = selectedIsland,
              let appDayOfWeek = currentAppDayOfWeek,
              let dayOfWeek = selectedDay else {
            errorMessage = "Gym, AppDayOfWeek, or DayOfWeek is not selected."
            print("Gym, AppDayOfWeek, or DayOfWeek is not selected.")
            return
        }
        
        // Proceed with using the unwrapped values
        print("Saving AppDayOfWeek: \(appDayOfWeek) with island: \(island) and dayOfWeek: \(dayOfWeek)")
        repository.updateAppDayOfWeek(appDayOfWeek, with: island, dayOfWeek: dayOfWeek, context: viewContext)
    }
    
    
    
    func fetchPirateIslands() {
        print("Fetching gym...")
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
    func ensureInitialization() {
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
        
        // Fetch and assign the current day of the week
        if let _ = fetchCurrentDayOfWeek(for: selectedIsland!, day: selectedDay, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 })) {
            print("Current day of the week initialized.")
        } else {
            print("Failed to fetch current day of the week.")
        }
    }
    
    // MARK: - Fetch Current Day Of Week
    // Populates the matTimesForDay dictionary with the scheduled mat times for each day
    func fetchCurrentDayOfWeek(for island: PirateIsland, day: DayOfWeek, selectedDayBinding: Binding<DayOfWeek?>) -> AppDayOfWeek? {
        if let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: day, pirateIsland: island, context: repository.getViewContext()) {
            selectedDayBinding.wrappedValue = day
            
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
            
            // Update matTimesForDay dictionary
            matTimesForDay[day] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
            
            return appDayOfWeek
        } else {
            print("Failed to fetch or create AppDayOfWeek for day: \(day) and island: \(island.islandName ?? "")")
            matTimesForDay[day] = []
            return nil
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
    ) {
        guard selectedIsland != nil else {
            print("Error1: Selected gym is not set. Please select an gym before adding a mat time.")
            return
        }
        
        // Use `addMatTimes` instead of `addMatTimesForDay`
        addMatTimes(day: day, matTimes: [(time: time, type: type, gi: gi, noGi: noGi, openMat: openMat, restrictions: restrictions, restrictionDescription: restrictionDescription, goodForBeginners: goodForBeginners, kids: kids)])
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
    ) throws {
        print("Using updateOrCreateMatTime, updating/creating MatTime for AppDayOfWeek with day:  \(appDayOfWeek.day)")
        
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
        }
        
        // Save context
        do {
            try viewContext.save()
            print("Context saved successfully.")
        } catch {
            print("Failed to save context: \(error)")
        }
        
        // Refresh mat times
        refreshMatTimes()
        print("MatTimes refreshed.")
    }
    // MARK: - Refresh MatTimes -     // Assuming you have a property to store the selected day
    func refreshMatTimes() {
        print("Refreshing MatTimes")
        if let selectedIsland = selectedIsland, let unwrappedSelectedDay = selectedDay {
            // Fetch and assign the current day of the week
            if let _ = fetchCurrentDayOfWeek(for: selectedIsland, day: unwrappedSelectedDay, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 })) {
                print("MatTimes refreshed successfully.")
            } else {
                print("Failed to refresh MatTimes.")
            }
        } else {
            print("Error: Either island or day is not selected.")
        }
        initializeNewMatTime()
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
    func updateDay(for island: PirateIsland, dayOfWeek: DayOfWeek) {
        print("Updating day settings for gym: \(island) and dayOfWeek: \(dayOfWeek)")
        
        // Fetch or create the AppDayOfWeek instance with context
        let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: dayOfWeek.rawValue, pirateIsland: island, context: viewContext)
        
        // Safely unwrap appDayOfWeek before passing it to the update method
        if let appDayOfWeek = appDayOfWeek {
            repository.updateAppDayOfWeek(appDayOfWeek, with: island, dayOfWeek: dayOfWeek, context: viewContext)
        } else {
            // Handle the case where appDayOfWeek is nil, if needed
            print("Failed to fetch or create AppDayOfWeek.")
        }
        
        saveData()
        refreshMatTimes()
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
    func initializeNewMatTime() {
        print("Initializing new MatTime")
        newMatTime = MatTime(context: viewContext)
    }
    
    // MARK: - Load Schedules
    func loadSchedules(for island: PirateIsland) {
        _ = NSPredicate(format: "pIsland == %@", island)
        let appDayOfWeeks = repository.fetchSchedules(for: island)
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
        
        schedules = schedulesDict
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
                                print("Gym: \(island.name ?? ""), MatTimes: \(matTimes)")
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
    func addNewMatTime() {
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
            addMatTime(matTime: unwrappedMatTime, for: day, appDayOfWeek: appDayOfWeek)
        } else {
            print("Error: newMatTime is unexpectedly nil")
        }
        
        saveData()
        newMatTime = nil // Reset newMatTime to nil
    }
    
    // MARK: - Add Mat Time
    func addMatTime(matTime: MatTime, for day: DayOfWeek, appDayOfWeek: AppDayOfWeek) {
        print("Adding MatTime: \(matTime) for day: \(day) and appDayOfWeek: \(appDayOfWeek)")
        
        // Check if the MatTime object is empty
        if matTime.time == nil || matTime.time == "" {
            print("WARNING: Empty MatTime object being added!")
        }
        
        // Create a new MatTime object
        let newMatTimeObject = MatTime(context: viewContext)  // Use viewContext here
        newMatTimeObject.time = matTime.time
        newMatTimeObject.type = matTime.type
        // Set other MatTime fields as needed
        
        // Assign the AppDayOfWeek to the new MatTime object
        newMatTimeObject.appDayOfWeek = appDayOfWeek
        
        // Add the MatTime to the AppDayOfWeek
        appDayOfWeek.addToMatTimes(newMatTimeObject)
        
        // Save the context
        saveData()
        print("Added MatTime: \(newMatTimeObject) FROM func addMatTime(matTime: MatTime, for day: DayOfWeek, appDayOfWeek: AppDayOfWeek)")    }
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
            saveEnabled = false
            return
        }
        
        saveEnabled = true
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
    func addMatTimes(
        day: DayOfWeek,
        matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, kids: Bool)]
    ) {
        print("Adding mat times: \(matTimes)")
        matTimes.forEach { matTime in
            print("Adding mat time: \(matTime)")
            let newMatTime = MatTime(context: viewContext)  // Ensure using viewContext here
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
            print("Configured mat time: \(newMatTime)")
            addMatTime(matTime: newMatTime, for: day)
        }
        print("Added \(matTimes.count) mat times for day: \(day)")
        
    }
    
    // MARK: - GENERAL ADD MAT TIME
    func addMatTime(
        matTime: MatTime? = nil,
        for day: DayOfWeek
    ) {
        guard let island = selectedIsland else {
            errorMessage = "Selected gym is not set."
            print("Error2: Selected gym is not set.")
            return
        }
        
        print("Adding mat time for day: \(day)")
        
        let appDayOfWeek = repository.getAppDayOfWeek(for: day.rawValue, pirateIsland: island, context: viewContext)
        
        guard let appDayOfWeek = appDayOfWeek else {
            errorMessage = "Failed to create or fetch AppDayOfWeek."
            print("Error: Failed to create or fetch AppDayOfWeek.")
            return
        }
        
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
            addOrUpdateMatTime(
                time: matTime.time ?? "",
                type: matTime.type ?? "",
                gi: matTime.gi,
                noGi: matTime.noGi,
                openMat: matTime.openMat,
                restrictions: matTime.restrictions,
                restrictionDescription: matTime.restrictionDescription ?? "",
                goodForBeginners: matTime.goodForBeginners,
                kids: matTime.kids,
                for: day
            )
        }
        
        saveData()
        refreshMatTimes()
        print("Mat times for day: \(day) - \(matTimesForDay[day] ?? []) FROM func addMatTime")
    }
    // MARK: - Remove MatTime
    func removeMatTime(_ matTime: MatTime) {
        print("Removing MatTime: \(matTime)")
        viewContext.delete(matTime)
        saveData()
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
            // Add a breakpoint here to inspect the call stack
            return
        }
        
        guard let selectedDay = self.selectedDay else {
            print("Error: Selected day is not set.")
            return
        }
        
        print("Updating schedules for island: \(selectedIsland) and day: \(selectedDay)")
        DispatchQueue.main.async {
            // Fetch AppDayOfWeek for the selected island and day
            if let appDayOfWeek = self.repository.fetchAppDayOfWeek(for: selectedDay.rawValue, pirateIsland: selectedIsland, context: self.viewContext) {
                self.selectedAppDayOfWeek = appDayOfWeek // Set selectedAppDayOfWeek
                
                // Update matTimesForDay dictionary
                self.matTimesForDay[selectedDay] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
                print("Updated mat times for day: \(selectedDay). Count: \(self.matTimesForDay[selectedDay]?.count ?? 0)")
            } else {
                self.selectedAppDayOfWeek = nil // Clear selectedAppDayOfWeek if not found
                print("No AppDayOfWeek found for day: \(selectedDay)")
            }
        }
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
            let islands = try await repository.fetchAllIslands(forDay: day.rawValue)
            print("Fetched islands: \(islands)")
            
            let filteredIslands = islands.filter { pirateIsland, _ in
                guard let appDayOfWeeks = pirateIsland.appDayOfWeeks else { return false }
                return appDayOfWeeks.contains { ($0 as? AppDayOfWeek)?.day == day.rawValue && ($0 as? AppDayOfWeek)?.matTimes?.contains { ($0 as? MatTime)?.time != nil } ?? false }
            }
            
            print("Filtered islands count: \(filteredIslands.count)")
            
            await MainActor.run {
                self.islandsWithMatTimes = filteredIslands
            }
        } catch {
            print("Error fetching islands: \(error.localizedDescription)")
            // Add more specific error handling if needed
        }
    }
    
    
    func updateCurrentDayAndMatTimes(for island: PirateIsland, day: DayOfWeek) {
        // Fetch the current day of the week and assign it to currentAppDayOfWeek
        if let appDayOfWeek = fetchCurrentDayOfWeek(for: island, day: day, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 })) {
            self.currentAppDayOfWeek = appDayOfWeek
            
            // Fetch mat times for the current day and update the state
            self.matTimesForDay[day] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
        } else {
            print("Could not update current day and mat times, no AppDayOfWeek returned.")
        }
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
