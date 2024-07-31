// AppDayOfWeekViewModel.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
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
        initializeDaySettings()
        fetchPirateIslands()

        if let island = selectedIsland {
            fetchCurrentDayOfWeek(for: island)
            loadSchedules(for: island)
        }
    }

    // MARK: - Validation
    func isDataValid() -> Bool {
        let isValid = !(name?.isEmpty ?? true) &&
                      !selectedType.isEmpty &&
                      selectedDays.count > 0
        return isValid
    }

    // MARK: - User Interaction
    func handleUserInteraction() {
        let isValid = isDataValid()
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
            appDayOfWeekList = try context.fetch(request)
            if let currentAppDayOfWeek = appDayOfWeekList.first {
                self.currentAppDayOfWeek = currentAppDayOfWeek
                print("Fetched AppDayOfWeek: \(currentAppDayOfWeek)")
                matTimesForDay[selectedDay] = currentAppDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
            } else {
                print("No AppDayOfWeek found for the given island.")
            }
        } catch {
            errorMessage = "Failed to fetch AppDayOfWeek: \(error.localizedDescription)"
            print("Failed to fetch AppDayOfWeek: \(error.localizedDescription)")
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
            matTimesForDay[day] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
        }
    }

    // MARK: - Save Context
    func saveContext() {
        do {
            try context.save()
        } catch {
            errorMessage = "Failed to save context: \(error.localizedDescription)"
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
    
    // MARK: - Function to Add or Update MatTime
    func addOrUpdateMatTime(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String, goodForBeginners: Bool, adult: Bool, for dayOfWeek: DayOfWeek) {
        // Ensure selectedAppDayOfWeek exists
        if currentAppDayOfWeek == nil {
            currentAppDayOfWeek = AppDayOfWeek(context: context)
            currentAppDayOfWeek?.day = dayOfWeek.rawValue
            currentAppDayOfWeek?.name = "" // Set appropriate value
            currentAppDayOfWeek?.appDayOfWeekID = "" // Set appropriate value

            if let island = selectedIsland {
                currentAppDayOfWeek?.pIsland = island
            }
        }

        if let appDayOfWeek = currentAppDayOfWeek {
            // Create or Update MatTime
            let newMatTime = MatTime(context: context) // Ensure this uses the same context
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
                try context.save()
                print("Successfully saved new MatTime with time: \(newMatTime.time ?? "nil")")
                refreshMatTimes() // Refresh the UI
            } catch {
                print("Failed to save new MatTime: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Refresh MatTimes
    func refreshMatTimes() {
        if let selectedIsland = selectedIsland {
            fetchAppDayOfWeekAndUpdateList(for: selectedIsland, day: selectedDay)
        }
    }
    
    // MARK: - Fetch MatTimes for Day
    func fetchMatTimes(for day: DayOfWeek) -> [MatTime] {
        let request: NSFetchRequest<MatTime> = MatTime.fetchRequest()
        request.predicate = NSPredicate(format: "appDayOfWeek.day == %@", day.rawValue)
        
        do {
            return try context.fetch(request)
        } catch {
            errorMessage = "Failed to fetch MatTime: \(error.localizedDescription)"
            return []
        }
    }
}
