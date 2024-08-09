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
    var selectedIsland: PirateIsland?
    @Published var currentAppDayOfWeek: AppDayOfWeek?
    @Published var appDayOfWeekList: [AppDayOfWeek] = []
    @Published var selectedDay: DayOfWeek = .monday
    @Published var appDayOfWeekID: String?
    @Published var saveEnabled: Bool = false
    @Published var schedules: [DayOfWeek: [AppDayOfWeek]] = [:]
    @Published var allIslands: [PirateIsland] = []
    @Published var errorMessage: String?
    @Published var newMatTime: MatTime?

    var viewContext: NSManagedObjectContext
    var repository: AppDayOfWeekRepository
    private let dataManager: PirateIslandDataManager

    // MARK: - Day Settings
    @Published var dayOfWeekStates: [DayOfWeek: Bool] = [:]
    @Published var giForDay: [DayOfWeek: Bool] = [:]
    @Published var noGiForDay: [DayOfWeek: Bool] = [:]
    @Published var openMatForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionsForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionDescriptionForDay: [DayOfWeek: String] = [:]
    @Published var goodForBeginnersForDay: [DayOfWeek: Bool] = [:]
    @Published var adultForDay: [DayOfWeek: Bool] = [:]
    @Published var matTimeForDay: [DayOfWeek: String] = [:]
    @Published var selectedTimeForDay: [DayOfWeek: Date] = [:]
    @Published var matTimesForDay: [DayOfWeek: [MatTime]] = [:]
    @Published var showError = false
    @Published var selectedAppDayOfWeek: AppDayOfWeek?

    // MARK: - Property Observers
    @Published var name: String? {
        didSet {
            print("Name updated: \(String(describing: name))")
            handleUserInteraction()
        }
    }

    @Published var selectedType: String = "" {
        didSet {
            print("Selected type updated: \(selectedType)")
            handleUserInteraction()
        }
    }

    @Published var selectedDays: Set<DayOfWeek> = [] {
        didSet {
            handleUserInteraction()
        }
    }
    
    // MARK: - DateFormatter
    public lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Choose the format that suits your needs
        return formatter
    }()
    
    // MARK: - Initializer
    init(selectedIsland: PirateIsland?, repository: AppDayOfWeekRepository, viewContext: NSManagedObjectContext) {
        self.selectedIsland = selectedIsland
        self.repository = repository
        self.viewContext = viewContext
        self.dataManager = PirateIslandDataManager(viewContext: viewContext)

        // Initialize newMatTime after viewContext is set
        self.newMatTime = MatTime(context: viewContext)
        
        print("AppDayOfWeekViewModel initialized with context: \(viewContext) and repository: \(repository)")

        // Initialize day settings and fetch islands
        initializeDaySettings()
        fetchPirateIslands()
        
        // Handle cases where selectedIsland might be nil
        if let island = selectedIsland {
            fetchCurrentDayOfWeek(for: island)
            loadSchedules(for: island)
        }
    }


    // MARK: - Methods
    // MARK: - Save Context
    func saveContext() {
        print("Saving context...")
        do {
            try viewContext.save()
            print("Context saved successfully.")
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
            errorMessage = "Failed to save context: \(error.localizedDescription)"
        }
    }
    
    func saveAppDayOfWeek() {
        guard let island = selectedIsland, let appDayOfWeek = currentAppDayOfWeek else {
            errorMessage = "Island or AppDayOfWeek is not selected."
            print("Island or AppDayOfWeek is not selected.")
            return
        }
        // Ensure this uses the correct day
        print("Saving AppDayOfWeek: \(appDayOfWeek) with island: \(island) and dayOfWeek: \(selectedDay)")
        repository.updateAppDayOfWeekName(appDayOfWeek, with: island, dayOfWeek: selectedDay)
    }



    
    func fetchPirateIslands() {
        allIslands = dataManager.fetchPirateIslands()
        print("Fetched Pirate Islands: \(allIslands)")

    }


    // MARK: - Ensure Initialization
    func ensureInitialization() {
        if selectedIsland == nil {
            errorMessage = "Island is not selected."
            print("Error: Island is not selected.")

            return
        }
        
        if currentAppDayOfWeek == nil {
            fetchCurrentDayOfWeek(for: selectedIsland!)
        }
    }
    
    
    // MARK: - Fetch Current Day Of Week
    func fetchCurrentDayOfWeek(for island: PirateIsland) {
        print("Fetching AppDayOfWeek for island: \(island) and day: \(selectedDay)")
        let fetchedAppDayOfWeeks = repository.fetchSchedules(for: island, day: selectedDay)
        
        guard let lastAppDayOfWeek = fetchedAppDayOfWeeks.last else {
            print("No AppDayOfWeek found for island: \(island) and day: \(selectedDay)")
            return
        }
        
        currentAppDayOfWeek = lastAppDayOfWeek
        matTimesForDay[selectedDay] = lastAppDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
        print("Fetched existing AppDayOfWeek: \(lastAppDayOfWeek) with MatTimes: \(matTimesForDay[selectedDay] ?? [])")
    }


    // MARK: - Add or Update Mat Time
    func addOrUpdateMatTime(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String, goodForBeginners: Bool, adult: Bool, for day: DayOfWeek) {
        print("Adding or updating MatTime for day: \(day)")

        // Safely unwrap `selectedIsland`
        guard let selectedIsland = selectedIsland else {
            print("Error: selectedIsland is nil")
            return
        }

        // Use `addMatTimes` instead of `addMatTimesForDay`
        addMatTimes(day: day, matTimes: [(time: time, type: type, gi: gi, noGi: noGi, openMat: openMat, restrictions: restrictions, restrictionDescription: restrictionDescription, goodForBeginners: goodForBeginners, adult: adult)])
        print("Added/Updated MatTime")
    }


    // MARK: - Update Or Create MatTime
    private func updateOrCreateMatTime(_ existingMatTime: MatTime?, time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String, goodForBeginners: Bool, adult: Bool, for appDayOfWeek: AppDayOfWeek) {
        // Log parameters
        print("updateOrCreateMatTime called with:")
        print("  Existing MatTime: \(String(describing: existingMatTime))")
        print("  Time: \(time)")
        print("  Type: \(type)")
        print("  Gi: \(gi)")
        print("  NoGi: \(noGi)")
        print("  OpenMat: \(openMat)")
        print("  Restrictions: \(restrictions)")
        print("  RestrictionDescription: \(restrictionDescription)")
        print("  GoodForBeginners: \(goodForBeginners)")
        print("  Adult: \(adult)")
        print("  AppDayOfWeek: \(appDayOfWeek)")

        if let existingMatTime = existingMatTime {
            print("Updating existing MatTime with ID: \(existingMatTime.id ?? UUID())")
            existingMatTime.configure(time: time, type: type, gi: gi, noGi: noGi, openMat: openMat, restrictions: restrictions, restrictionDescription: restrictionDescription, goodForBeginners: goodForBeginners, adult: adult)
            print("Updated MatTime details: \(existingMatTime)")
        } else {
            print("Creating new MatTime")
            let newMatTime = MatTime(context: viewContext)
            newMatTime.configure(time: time, type: type, gi: gi, noGi: noGi, openMat: openMat, restrictions: restrictions, restrictionDescription: restrictionDescription, goodForBeginners: goodForBeginners, adult: adult)
            appDayOfWeek.addToMatTimes(newMatTime)
            print("Created new MatTime with ID: \(newMatTime.id ?? UUID())")
            print("New MatTime details: \(newMatTime)")
        }

        // Save context
        saveContext()
        refreshMatTimes()
        print("MatTimes refreshed.")

        // Refresh mat times
        refreshMatTimes()
        print("MatTimes refreshed.")
    }


    // MARK: - Refresh MatTimes
    func refreshMatTimes() {
        print("Refreshing MatTimes")
        if let selectedIsland = selectedIsland {
            fetchCurrentDayOfWeek(for: selectedIsland)
        }
        initializeNewMatTime()
    }
    // MARK: - Fetch MatTimes for Day
    func fetchMatTimes(for day: DayOfWeek) -> [MatTime] {
        print("Fetching MatTimes for day: \(day)")
        let request: NSFetchRequest<MatTime> = MatTime.fetchRequest()
        request.predicate = NSPredicate(format: "appDayOfWeek.day == %@", day.rawValue)

        do {
            let fetchedMatTimes = try viewContext.fetch(request)
            print("Fetched MatTimes: \(fetchedMatTimes)")
            return fetchedMatTimes
        } catch {
            print("Error fetching MatTimes: \(error.localizedDescription)")
            return []
        }
    }
    // MARK: - Update Day
    func updateDay(for island: PirateIsland, dayOfWeek: DayOfWeek) {
        print("Updating day settings for island: \(island) and dayOfWeek: \(dayOfWeek)")
        
        let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: dayOfWeek.rawValue, pirateIsland: island)
        
        repository.updateAppDayOfWeek(appDayOfWeek, with: island, dayOfWeek: dayOfWeek)
        saveContext()
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
            adultForDay[day] = false
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
        let appDayOfWeeks = repository.fetchSchedules(for: island)
        var schedulesDict: [DayOfWeek: [AppDayOfWeek]] = [:]
        
        for appDayOfWeek in appDayOfWeeks {
            // Replace `day` with the actual property name in AppDayOfWeek
            if let dayValue = appDayOfWeek.day { // Adjust 'day' to match the actual property name
                if let day = DayOfWeek(rawValue: dayValue) {
                    // Initialize the array if it doesn't exist for the given day
                    if schedulesDict[day] == nil {
                        schedulesDict[day] = []
                    }
                    // Append the current `appDayOfWeek` to the array for that day
                    schedulesDict[day]?.append(appDayOfWeek)
                } else {
                    print("Warning: Invalid day value '\(dayValue)'")
                }
            } else {
                print("Warning: AppDayOfWeek has no day set.")
            }
        }
        
        // Update the schedules property
        schedules = schedulesDict
        print("Loaded schedules: \(schedules)")
    }

    
    // MARK: - Fetch and Update List of AppDayOfWeek for a Specific Day
    func fetchAppDayOfWeekAndUpdateList(for island: PirateIsland, day: DayOfWeek) {
        print("Fetching AppDayOfWeek for island: \(island) and day: \(day)")
        if let appDayOfWeek = repository.fetchAppDayOfWeek(for: island, day: day) {
            matTimesForDay[day] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
            print("Updated matTimesForDay for \(day): \(matTimesForDay[day] ?? [])")
        } else {
            print("No AppDayOfWeek found for \(day) on island \(island).")
        }
    }
    // MARK: - Equatable Implementation
    static func == (lhs: AppDayOfWeekViewModel, rhs: AppDayOfWeekViewModel) -> Bool {
        print("Comparing AppDayOfWeekViewModel instances for equality")
        return lhs.selectedDay == rhs.selectedDay &&
               lhs.selectedIsland == rhs.selectedIsland &&
               lhs.currentAppDayOfWeek == rhs.currentAppDayOfWeek &&
               lhs.appDayOfWeekList == rhs.appDayOfWeekList &&
               lhs.schedules == rhs.schedules &&
               lhs.allIslands == rhs.allIslands &&
               lhs.errorMessage == rhs.errorMessage &&
               lhs.dayOfWeekStates == rhs.dayOfWeekStates &&
               lhs.giForDay == rhs.giForDay &&
               lhs.noGiForDay == rhs.noGiForDay &&
               lhs.openMatForDay == rhs.openMatForDay &&
               lhs.restrictionsForDay == rhs.restrictionsForDay &&
               lhs.restrictionDescriptionForDay == rhs.restrictionDescriptionForDay &&
               lhs.goodForBeginnersForDay == rhs.goodForBeginnersForDay &&
               lhs.adultForDay == rhs.adultForDay &&
               lhs.matTimeForDay == rhs.matTimeForDay &&
               lhs.selectedTimeForDay == rhs.selectedTimeForDay &&
               lhs.matTimesForDay == rhs.matTimesForDay &&
               lhs.showError == rhs.showError &&
               lhs.selectedAppDayOfWeek == rhs.selectedAppDayOfWeek &&
               lhs.name == rhs.name &&
               lhs.selectedType == rhs.selectedType &&
               lhs.selectedDays == rhs.selectedDays
    }
    
    // MARK: - Add New Mat Time
    func addNewMatTime() {
        print("Attempting to add new MatTime")
        print("Current AppDayOfWeek: \(String(describing: currentAppDayOfWeek))")
        print("New MatTime: \(String(describing: newMatTime))")
        print("Selected Day: \(selectedDay)") // Directly use selectedDay if it's non-optional

        // Ensure currentAppDayOfWeek is not nil
        guard let appDayOfWeek = currentAppDayOfWeek else {
            print("Current AppDayOfWeek is not set")
            errorMessage = "Current AppDayOfWeek is not set."
            return
        }

        // Ensure newMatTime is not nil
        guard let newMatTime = newMatTime else {
            errorMessage = "New MatTime is nil."
            print("Error: New MatTime is nil.")
            return
        }

        // Check for duplicate MatTime
        if handleDuplicateMatTime(for: selectedDay, with: newMatTime) {
            errorMessage = "MatTime already exists for this day."
            print("Error: MatTime already exists for the selected day.")
            return
        }

        newMatTime.createdTimestamp = Date()

        // Add or update MatTime
        addOrUpdateMatTime(
            time: newMatTime.time ?? "",
            type: newMatTime.type ?? "",
            gi: newMatTime.gi,
            noGi: newMatTime.noGi,
            openMat: newMatTime.openMat,
            restrictions: newMatTime.restrictions,
            restrictionDescription: newMatTime.restrictionDescription ?? "",
            goodForBeginners: newMatTime.goodForBeginners,
            adult: newMatTime.adult,
            for: selectedDay
        )

        print("Added Mat Time with AppDayOfWeek ID: \(appDayOfWeek.appDayOfWeekID ?? "None")")
        updateBindings()
        saveContext()
        initializeNewMatTime()
    }


    
    // MARK: - Update Bindings
    func updateBindings() {
        print("Updating bindings...")
        print("Selected Island: \(String(describing: selectedIsland))")
        print("Current AppDayOfWeek: \(String(describing: currentAppDayOfWeek))")
        print("New MatTime: \(String(describing: newMatTime))")
    }

    
    // MARK: - Validate Fields
    func validateFields() -> Bool {
        let isValid = !(name?.isEmpty ?? true) && !selectedType.isEmpty && selectedDays.count > 0
        print("Validation result: \(isValid). Name: \(name ?? "nil"), Selected Type: \(selectedType), Selected Days Count: \(selectedDays.count)")
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
        print("Selected island set to: \(island)")
    }
    func setCurrentAppDayOfWeek(_ appDayOfWeek: AppDayOfWeek) {
        self.currentAppDayOfWeek = appDayOfWeek
        repository.setCurrentAppDayOfWeek(appDayOfWeek)
        print("Current AppDayOfWeek set to: \(appDayOfWeek)")
    }
    
    
    // MARK: - Add Mat Times For Day
    func addMatTimes(
        day: DayOfWeek,
        matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, adult: Bool)]
    ) {
        guard let island = selectedIsland else {
            print("Error: Selected island is not set.")
            return
        }
        
        print("Adding mat times for day: \(day). MatTimes count: \(matTimes.count)")
        
        var appDayOfWeek: AppDayOfWeek?
        if let existingAppDayOfWeek = repository.fetchAppDayOfWeek(for: island, day: day) {
            appDayOfWeek = existingAppDayOfWeek
        } else {
            appDayOfWeek = repository.createAppDayOfWeek(with: island, dayOfWeek: day)
        }
        
        guard let appDayOfWeek = appDayOfWeek else {
            print("Error: Failed to create or fetch AppDayOfWeek.")
            return
        }
        
        currentAppDayOfWeek = appDayOfWeek
        
        print("Adding MatTimes for day: \(day) to AppDayOfWeek: \(appDayOfWeek)")
        matTimes.forEach { matTime in
            let newMatTime = MatTime(context: self.viewContext)
            newMatTime.configure(
                time: matTime.time,
                type: matTime.type,
                gi: matTime.gi,
                noGi: matTime.noGi,
                openMat: matTime.openMat,
                restrictions: matTime.restrictions,
                restrictionDescription: matTime.restrictionDescription,
                goodForBeginners: matTime.goodForBeginners,
                adult: matTime.adult
            )
            appDayOfWeek.addToMatTimes(newMatTime)
            print("Configured MatTime: \(newMatTime)")
        }
        
        saveContext()
        refreshMatTimes()
    }

    // MARK: - Remove MatTime
    func removeMatTime(_ matTime: MatTime) {
        print("Removing MatTime: \(matTime)")
        viewContext.delete(matTime)
        saveContext()
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
            print("Error: Selected island is not set.")
            return
        }
        
        print("Updating schedules for island: \(selectedIsland) and day: \(self.selectedDay)")
        DispatchQueue.main.async {
            self.appDayOfWeekList = [self.repository.fetchAppDayOfWeek(for: selectedIsland, day: self.selectedDay)].compactMap { $0 }
            if let appDayOfWeek = self.appDayOfWeekList.first {
                self.matTimesForDay[self.selectedDay] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
                print("Updated mat times for day: \(self.selectedDay). Count: \(self.matTimesForDay[self.selectedDay]?.count ?? 0)")
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
        self.adult = false
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
        adult: Bool = false
    ) {
        self.time = time
        self.type = type
        self.gi = gi
        self.noGi = noGi
        self.openMat = openMat
        self.restrictions = restrictions
        self.restrictionDescription = restrictionDescription
        self.goodForBeginners = goodForBeginners
        self.adult = adult
    }
    
}

private extension String {
    var isNilOrEmpty: Bool {
        return self.isEmpty || self == "nil"
    }
}
