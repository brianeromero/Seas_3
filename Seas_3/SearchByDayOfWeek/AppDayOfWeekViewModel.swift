// AppDayOfWeekViewModel.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Foundation
import Combine
import CoreData

class AppDayOfWeekViewModel: ObservableObject {
    // MARK: - Properties
    @Published var appDayOfWeekList: [AppDayOfWeek] = []

    var selectedIsland: PirateIsland?
    private var repository: AppDayOfWeekRepository
    private var cancellables: Set<AnyCancellable> = []
    private var viewContext: NSManagedObjectContext
    
    // MARK: - Published Properties
    @Published var selectedDay: DayOfWeek = .monday
    @Published var appDayOfWeekID: String?
    @Published var saveEnabled: Bool = false
    @Published var currentAppDayOfWeek: AppDayOfWeek?
    @Published var schedules: [DayOfWeek: [AppDayOfWeek]] = [:]
    @Published var allIslands: [PirateIsland] = []
    @Published var errorMessage: String?
    @Published var newMatTime: MatTime?

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

    
    // MARK: - PROPERTYOBSERVERS

    @Published var name: String? {
        didSet {
            handleUserInteraction()
        }
    }

    @Published var selectedType: String = "" {
        didSet {
            handleUserInteraction()
        }
    }

    @Published var selectedDays: Set<DayOfWeek> = [] {
        didSet {
            handleUserInteraction()
        }
    }
    // MARK: - DateFormatter
    public var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Choose the format that suits your needs
        return formatter
    }

    // MARK: - Initializer
    init(selectedIsland: PirateIsland? = nil, repository: AppDayOfWeekRepository = AppDayOfWeekRepository.shared, viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.selectedIsland = selectedIsland
        self.repository = repository
        self.viewContext = viewContext
        initializeDaySettings()
        fetchPirateIslands()
        
        if let island = selectedIsland {
            fetchCurrentDayOfWeek(for: island)
            loadSchedules(for: island)
        }
    }

    // MARK: - Methods
    func saveContext() {
        print("AppDayOfWeekViewModel - Saving context")
        do {
            try viewContext.save()
            print("Context saved successfully")
        } catch {
            errorMessage = "Failed to save context: \(error.localizedDescription)"
        }
    }
    
    func fetchPirateIslands() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            allIslands = try viewContext.fetch(fetchRequest)
        } catch {
            errorMessage = "Failed to fetch pirate islands: \(error.localizedDescription)"
        }
    }

    func fetchCurrentDayOfWeek(for island: PirateIsland) {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "pIsland == %@", island)
        
        do {
            appDayOfWeekList = try viewContext.fetch(request)
            if let currentAppDayOfWeek = appDayOfWeekList.first {
                self.currentAppDayOfWeek = currentAppDayOfWeek
                matTimesForDay[selectedDay] = currentAppDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
            }
        } catch {
            errorMessage = "Failed to fetch AppDayOfWeek: \(error.localizedDescription)"
        }
    }

    func addOrUpdateMatTime(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, adult: Bool, for dayOfWeek: DayOfWeek) {
        // Fetch or create the AppDayOfWeek
        let appDayOfWeek = repository.fetchOrCreateAppDayOfWeek(for: selectedIsland ?? PirateIsland(), day: dayOfWeek)

        if let appDayOfWeek = appDayOfWeek {
            let newMatTime = MatTime(context: viewContext)
            newMatTime.time = time
            newMatTime.type = type
            newMatTime.gi = gi
            newMatTime.noGi = noGi
            newMatTime.openMat = openMat
            newMatTime.restrictions = restrictions
            newMatTime.restrictionDescription = restrictionDescription
            newMatTime.goodForBeginners = goodForBeginners
            newMatTime.adult = adult

            appDayOfWeek.addToMatTimes(newMatTime)

            do {
                try viewContext.save()
                print("Context saved successfully")
                refreshMatTimes() // Refresh the UI
            } catch {
                errorMessage = "Failed to save new MatTime: \(error.localizedDescription)"
            }
        }
    }
    // MARK: - Refresh MatTimes
    func refreshMatTimes() {
        if let selectedIsland = selectedIsland {
            fetchCurrentDayOfWeek(for: selectedIsland)
        }
        initializeNewMatTime()
    }

    // MARK: - Fetch MatTimes for Day
    func fetchMatTimes(for day: DayOfWeek) -> [MatTime] {
        let request: NSFetchRequest<MatTime> = MatTime.fetchRequest()
        request.predicate = NSPredicate(format: "appDayOfWeek.day == %@", day.rawValue)

        do {
            return try viewContext.fetch(request)
        } catch {
            errorMessage = "Failed to fetch MatTime: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - Update Day
    func updateDay(for island: PirateIsland, newDay: String) {
        // Print statement to track the update process
        print("Updating day for island: \(island.islandName) to \(newDay)")
        
        // Fetch the existing AppDayOfWeek for the selected day
        guard let appDayOfWeek = repository.fetchAppDayOfWeekFromPersistence(for: island, day: selectedDay).first else {
            print("No AppDayOfWeek found for the selected day.")
            return
        }

        // Update the day property
        appDayOfWeek.day = newDay

        // Call updateNameAndID without arguments
        updateNameAndID()

        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to update AppDayOfWeek: \(error.localizedDescription)"
        }
    }

    // MARK: - Generate Name for Day
    func generateNameForDay(day: DayOfWeek) -> String {
        return generateName(for: selectedIsland ?? PirateIsland(), day: day)
    }

    // MARK: - Generate AppDayOfWeek ID
    func generateAppDayOfWeekID(island: PirateIsland, day: DayOfWeek) -> String {
        guard let islandName = island.name else {
            print("Island name is nil")
            return ""
        }
        
        let dayNumber = day.number
        
        return "\(islandName)_\(day.rawValue)_\(dayNumber)"
    }
    // MARK: - Update Name and ID
    func updateNameAndID() {
        guard let island = selectedIsland, let appDayOfWeek = currentAppDayOfWeek else {
            name = ""
            appDayOfWeekID = ""
            return
        }

        self.name = generateName(for: island, day: selectedDay)
        self.appDayOfWeekID = generateAppDayOfWeekID(island: island, day: selectedDay)

        appDayOfWeek.name = self.name
        appDayOfWeek.appDayOfWeekID = self.appDayOfWeekID

        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to update AppDayOfWeek: \(error.localizedDescription)"
        }
    }


    // MARK: - Initialize Day Settings
    func initializeDaySettings() {
        DayOfWeek.allCases.forEach { day in
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
    }
    
    // MARK: - Initialize New MatTime
    func initializeNewMatTime() {
        newMatTime = MatTime(context: viewContext)
        newMatTime?.time = ""
        newMatTime?.type = ""
        newMatTime?.gi = false
        newMatTime?.noGi = false
        newMatTime?.openMat = false
        newMatTime?.restrictions = false
        newMatTime?.restrictionDescription = ""
        newMatTime?.goodForBeginners = false
        newMatTime?.adult = false
    }
    
    // MARK: - Load Schedules
    func loadSchedules(for island: PirateIsland) {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "pIsland == %@", island)
        
        do {
            let fetchedSchedules = try viewContext.fetch(request)
            
            // Organize schedules by day of the week
            var schedulesDict: [DayOfWeek: [AppDayOfWeek]] = [:]
            
            for schedule in fetchedSchedules {
                guard let dayString = schedule.day,
                      let day = DayOfWeek(rawValue: dayString) else {
                    continue
                }
                if schedulesDict[day] == nil {
                    schedulesDict[day] = []
                }
                schedulesDict[day]?.append(schedule)
            }
            
            // Update the published property
            self.schedules = schedulesDict
            
        } catch {
            errorMessage = "Failed to load schedules: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Fetch and Update List of AppDayOfWeek for a Specific Day
    func fetchAppDayOfWeekAndUpdateList(for island: PirateIsland, day: DayOfWeek) {
        appDayOfWeekList = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        
        if let appDayOfWeek = appDayOfWeekList.first {
            matTimesForDay[day] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
        }
    }
    
    // MARK: - Equatable Implementation
    static func == (lhs: AppDayOfWeekViewModel, rhs: AppDayOfWeekViewModel) -> Bool {
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
               lhs.selectedDays == rhs.selectedDays
    }
    
    
    
    func addNewMatTime() {
        guard let newMatTime = newMatTime else {
            errorMessage = "Please complete all fields."
            return
        }

        // Prepare the AppDayOfWeek entity
        updateNameAndID()
        
        // Add or update the MatTime
        addOrUpdateMatTime(
            time: newMatTime.time ?? "",
            type: "", // Set the type to an empty string for now
            gi: newMatTime.gi,
            noGi: newMatTime.noGi,
            openMat: newMatTime.openMat,
            restrictions: newMatTime.restrictions,
            restrictionDescription: newMatTime.restrictionDescription ?? "",
            goodForBeginners: newMatTime.goodForBeginners,
            adult: newMatTime.adult,
            for: selectedDay
        )

        print("Added Mat Time with AppDayOfWeek ID: \(currentAppDayOfWeek?.appDayOfWeekID ?? "None")")

        // Update bindings and save context
        updateBindings()
        saveContext()

        // Initialize new MatTime
        initializeNewMatTime()
    }


    func updateBindings() {
        // Update selectedAppDayOfWeek, name, and appDayOfWeekID bindings here
        // For example:
        selectedAppDayOfWeek = currentAppDayOfWeek
        name = currentAppDayOfWeek?.name ?? ""
        appDayOfWeekID = currentAppDayOfWeek?.appDayOfWeekID
    }
    
    
    // MARK: - Validation
    func validateFields() -> Bool {
        let isValid = !(name?.isEmpty ?? true) &&
                      !selectedType.isEmpty &&
                      selectedDays.count > 0
        return isValid
    }

    // MARK: - Computed Property for Save Button Enabling
    var isSaveEnabled: Bool {
        return validateFields()
    }

    // MARK: - User Interaction
    func handleUserInteraction() {
        let isValid = validateFields()
        saveEnabled = isValid
    }

    // MARK: - Binding for Day Selection
    func binding(for day: DayOfWeek) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.dayOfWeekStates[day] ?? false },
            set: { self.dayOfWeekStates[day] = $0 }
        )
    }

    // MARK: - Add MatTimes for Day
    func addMatTimesForDay(
        day: DayOfWeek,
        matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, adult: Bool)],
        for island: PirateIsland
    ) {
        matTimes.forEach { matTime in
            let newMatTime = MatTime(context: viewContext)
            newMatTime.time = matTime.time
            newMatTime.type = matTime.type
            newMatTime.gi = matTime.gi
            newMatTime.noGi = matTime.noGi
            newMatTime.openMat = matTime.openMat
            newMatTime.restrictions = matTime.restrictions
            newMatTime.restrictionDescription = matTime.restrictionDescription
            newMatTime.goodForBeginners = matTime.goodForBeginners
            newMatTime.adult = matTime.adult
            
            if currentAppDayOfWeek == nil {
                currentAppDayOfWeek = AppDayOfWeek(context: viewContext)
                currentAppDayOfWeek?.day = day.rawValue
                currentAppDayOfWeek?.name = generateNameForDay(day: day)
                currentAppDayOfWeek?.appDayOfWeekID = generateAppDayOfWeekID(island: island, day: day)
                currentAppDayOfWeek?.pIsland = island
            }
            
            currentAppDayOfWeek?.addToMatTimes(newMatTime)

            do {
                try viewContext.save()
                print("Context saved successfully")
                refreshMatTimes()
            } catch {
                errorMessage = "Failed to save new MatTime: \(error.localizedDescription)"
            }
        }
    }


    // MARK: - Remove MatTime
    func removeMatTime(_ matTime: MatTime) {
        viewContext.delete(matTime)
        saveContext()
    }

    // MARK: - Clear Selections
    func clearSelections() {
        DayOfWeek.allCases.forEach { day in
            dayOfWeekStates[day] = false
        }
    }

    // MARK: - Toggle Day Selection
    func toggleDaySelection(_ day: DayOfWeek) {
        dayOfWeekStates[day] = !(dayOfWeekStates[day] ?? false)
    }

    // MARK: - Check if a Day is Selected
    func isSelected(_ day: DayOfWeek) -> Bool {
        dayOfWeekStates[day] ?? false
    }

    // MARK: - Update Schedules
    func updateSchedules() {
        guard let selectedIsland = self.selectedIsland else {
            // Handle the case where selectedIsland is nil
            return
        }
        
        DispatchQueue.main.async {
            self.appDayOfWeekList = self.repository.fetchAppDayOfWeekFromPersistence(for: selectedIsland, day: self.selectedDay)
            if let appDayOfWeek = self.appDayOfWeekList.first {
                self.matTimesForDay[self.selectedDay] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
            }
        }
    }
    
    func generateName(for island: PirateIsland, day: DayOfWeek) -> String {
        return "\(island.name ?? "UnknownIsland") \(day.displayName)"
    }
    
    func generateAppDayOfWeekID(day: DayOfWeek) -> String {
        let islandName = selectedIsland?.name ?? "UnknownIsland"
        return "\(islandName)-\(day.rawValue)"
    }


    
}

extension MatTime {
    func reset() {
        self.time = nil
        self.gi = false
        self.noGi = false
        self.openMat = false
        self.restrictions = false
        self.restrictionDescription = nil
        self.goodForBeginners = false
        self.adult = false
    }

    func isEqual(to other: MatTime) -> Bool {
        return self.time == other.time &&
               self.gi == other.gi &&
               self.noGi == other.noGi &&
               self.openMat == other.openMat &&
               self.restrictions == other.restrictions &&
               self.restrictionDescription == other.restrictionDescription &&
               self.goodForBeginners == other.goodForBeginners &&
               self.adult == other.adult
    }
}
