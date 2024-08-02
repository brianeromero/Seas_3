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
    private let persistenceController = PersistenceController.shared
    private var cancellables: Set<AnyCancellable> = []

    var viewContext: NSManagedObjectContext
    
    // MARK: - Published Properties
    @Published var name: String?
    @Published var selectedType: String = ""
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
    @Published var selectedDays: Set<DayOfWeek> = []

    // MARK: - Computed Property for Context
    var context: NSManagedObjectContext {
        persistenceController.viewContext
    }

    // MARK: - DateFormatter
    public var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Choose the format that suits your needs
        return formatter
    }

    // MARK: - Initializer
    init(selectedIsland: PirateIsland? = nil, repository: AppDayOfWeekRepository = AppDayOfWeekRepository.shared) {
        self.selectedIsland = selectedIsland
        self.repository = repository
        self.viewContext = PersistenceController.shared.container.viewContext
        
        initializeDaySettings()
        fetchPirateIslands()
        
        if let island = selectedIsland {
            fetchCurrentDayOfWeek(for: island)
            loadSchedules(for: island)
        }
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

    // MARK: - Initialize Day Settings
    private func initializeDaySettings() {
        DayOfWeek.allCases.forEach { day in
            matTimeForDay[day] = ""
            selectedTimeForDay[day] = Date()
            goodForBeginnersForDay[day] = false
            giForDay[day] = false
            noGiForDay[day] = false
            openMatForDay[day] = false
            restrictionsForDay[day] = false
            restrictionDescriptionForDay[day] = ""
            matTimesForDay[day] = []
        }
    }

    // MARK: - Add MatTimes for Day
    func addMatTimesForDay(
        day: DayOfWeek,
        matTimes: [(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String?, goodForBeginners: Bool, adult: Bool)],
        for island: PirateIsland
    ) {
        repository.addMatTimesForDay(day: day, matTimes: matTimes, for: island)
    }

    // MARK: - Remove MatTime
    func removeMatTime(_ matTime: MatTime) {
        context.delete(matTime)
        saveContext()
    }

    // MARK: - Load Schedules for the Island
    func loadSchedules(for island: PirateIsland) {
        DayOfWeek.allCases.forEach { day in
            schedules[day] = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        }
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

    // MARK: - Fetch Pirate Islands
    func fetchPirateIslands() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            allIslands = try context.fetch(fetchRequest)
        } catch {
            errorMessage = "Failed to fetch pirate islands: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Current Day of the Week for the Island
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

    // MARK: - Select a Day
    func selectDay(_ day: DayOfWeek) {
        selectedDay = day
    }

    // MARK: - Fetch and Update List of AppDayOfWeek for a Specific Day
    func fetchAppDayOfWeekAndUpdateList(for island: PirateIsland, day: DayOfWeek) {
        self.appDayOfWeekList = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        if let appDayOfWeek = self.appDayOfWeekList.first {
            self.matTimesForDay[day] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
        }
    }

    // MARK: - Save Context
    func saveContext() {
        do {
            try viewContext.save()
            print("Context saved successfully")

        } catch {
            errorMessage = "Failed to save context: \(error.localizedDescription)"
            print("Failed to save context: \(error.localizedDescription)")

        }
    }

    // MARK: - Function to Add or Update MatTime
    func addOrUpdateMatTime(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String, goodForBeginners: Bool, adult: Bool, for dayOfWeek: DayOfWeek) {
        if currentAppDayOfWeek == nil {
            currentAppDayOfWeek = AppDayOfWeek(context: viewContext)
            currentAppDayOfWeek?.day = dayOfWeek.rawValue
            currentAppDayOfWeek?.name = name ?? "" // Set appropriate value
            currentAppDayOfWeek?.appDayOfWeekID = appDayOfWeekID ?? "" // Set appropriate value

            if let island = selectedIsland {
                currentAppDayOfWeek?.pIsland = island // Set the pIsland relationship
            }
        }

        if let appDayOfWeek = currentAppDayOfWeek, let newMatTime = newMatTime {
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

        // Update the day property and save the context
        appDayOfWeek.day = newDay
        appDayOfWeek.name = generateNameForDay(day: DayOfWeek(rawValue: newDay) ?? .monday)
        appDayOfWeek.appDayOfWeekID = generateAppDayOfWeekID(island: island, day: newDay)

        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to update AppDayOfWeek: \(error.localizedDescription)"
        }
    }


    // MARK: - Generate Name for Day
    private func generateNameForDay(day: DayOfWeek) -> String {
        return "\(selectedIsland?.name ?? "UnknownIsland") - \(day.displayName)"
    }

    // MARK: - Generate AppDayOfWeek ID
    private func generateAppDayOfWeekID(island: PirateIsland, day: String) -> String {
        guard let islandName = island.name else {
            print("Island name is nil")
            return ""
        }
        
        guard let dayNumber = DayOfWeek(rawValue: day)?.number else {
            print("Day number is nil")
            return ""
        }
        
        return "\(islandName)_\(day)_\(dayNumber)"
    }
    // MARK: - Update Name and ID
    func updateNameAndID() {
        guard let island = selectedIsland, let appDayOfWeek = currentAppDayOfWeek else {
            name = ""
            appDayOfWeekID = ""
            return
        }
        
        guard let dayName = appDayOfWeek.day else {
            print("Day is nil")
            return
        }
        
        let islandName = island.islandName
        let dayNumber = DayOfWeek(rawValue: dayName)?.number ?? 0

        // Print statement to indicate the start of the update
        print("Updating name and ID...")
        
        // Update the Core Data entity
        appDayOfWeek.name = "\(islandName) \(dayName)"
        appDayOfWeek.appDayOfWeekID = "\(islandName) \(dayName) \(dayNumber)"
        
        // Print statements to confirm the updated values
        print("Updated Name: \(appDayOfWeek.name ?? "none")")
        print("Updated AppDayOfWeekID: \(appDayOfWeek.appDayOfWeekID ?? "none")")
        
        // Update the local @Published properties
        name = "\(islandName) \(dayName)"
        appDayOfWeekID = "\(islandName) \(dayName) \(dayNumber)"
        
        // Save the context to persist the changes
        saveContext()
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
    
    
    func initializeNewMatTime() {
        newMatTime = MatTime(context: viewContext)
    }
}
