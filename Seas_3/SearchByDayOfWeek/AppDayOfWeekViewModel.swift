// AppDayOfWeekViewModel.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Combine
import CoreData

class AppDayOfWeekViewModel: ObservableObject {
    // MARK: - Properties
    
    var selectedIsland: PirateIsland?
    private var repository = AppDayOfWeekRepository.shared
    private let persistenceController = PersistenceController.shared
    private var cancellables: Set<AnyCancellable> = []
    


    // MARK: - Published Properties
    @Published var appDayOfWeekList: [AppDayOfWeek] = [] {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
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
    
    // MARK: - Context
    var context: NSManagedObjectContext {
        persistenceController.viewContext
    }

    // MARK: - DateFormatter
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()

    // MARK: - Initializer
    init(selectedIsland: PirateIsland?, repository: AppDayOfWeekRepository = AppDayOfWeekRepository.shared) {
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
        // Example validation logic
        // Ensure required fields are filled
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

    // MARK: - Binding for day selection
    func binding(for day: DayOfWeek) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.dayOfWeekStates[day] ?? false },
            set: { self.dayOfWeekStates[day] = $0 }
        )
    }

    // MARK: - Initialize day settings
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

    // MARK: - AddMatTimesForDay
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

    // MARK: - Load schedules for the island
    func loadSchedules(for island: PirateIsland) {
        DayOfWeek.allCases.forEach { day in
            schedules[day] = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        }
    }

    // MARK: - Update schedules
    func updateSchedules() {
        guard let selectedIsland = self.selectedIsland else {
            // Handle the case where selectedIsland is nil
            return
        }
        
        DispatchQueue.main.async {
            // Update the @Published property here
            self.appDayOfWeekList = self.repository.fetchAppDayOfWeekFromPersistence(for: selectedIsland, day: self.selectedDay)
        }
    }
    // MARK: - Clear selections
    func clearSelections() {
        DayOfWeek.allCases.forEach { day in
            dayOfWeekStates[day] = false
        }
    }

    // MARK: - Toggle day selection
    func toggleDaySelection(_ day: DayOfWeek) {
        dayOfWeekStates[day] = !(dayOfWeekStates[day] ?? false)
    }

    // MARK: - Check if a day is selected
    func isSelected(_ day: DayOfWeek) -> Bool {
        dayOfWeekStates[day] ?? false
    }

    // MARK: - Fetch pirate islands
    func fetchPirateIslands() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            allIslands = try context.fetch(fetchRequest)
        } catch {
            errorMessage = "Failed to fetch pirate islands: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch current day of the week for the island
    func fetchCurrentDayOfWeek(for island: PirateIsland) {
        let day = selectedDay

        let fetchedDays = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        self.currentAppDayOfWeek = fetchedDays.first

        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "pIsland == %@", island)

        do {
            appDayOfWeekList = try context.fetch(request)
            appDayOfWeekList.forEach {
                print("Day: \($0.day ?? "N/A"), Times: \($0.matTimes?.compactMap { ($0 as? MatTime)?.time }.joined(separator: ", ") ?? "N/A")")
            }
        } catch {
            errorMessage = "Failed to fetch AppDayOfWeek: \(error.localizedDescription)"
        }
    }

    // MARK: - Select a day
    func selectDay(_ day: DayOfWeek) {
        selectedDay = day
    }

    // MARK: - Fetch and update list of AppDayOfWeek for a specific day
    func fetchAppDayOfWeekAndUpdateList(for island: PirateIsland, day: DayOfWeek) {
        self.appDayOfWeekList = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        if let appDayOfWeek = self.appDayOfWeekList.first {
            matTimesForDay[day] = appDayOfWeek.matTimes?.allObjects as? [MatTime] ?? []
        }
    }

    // MARK: - Save context
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


    // MARK: - Computed property for save button enabling
    var isSaveEnabled: Bool {
        return validateFields()
    }

    // MARK: - Equatable implementation
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
    
    // MARK: - Function to add or update MatTime

    func addOrUpdateMatTime(time: String, type: String, gi: Bool, noGi: Bool, openMat: Bool, restrictions: Bool, restrictionDescription: String, goodForBeginners: Bool, adult: Bool) {
        let newMatTime = MatTime(context: context)
        newMatTime.time = time
        newMatTime.type = type
        newMatTime.gi = gi
        newMatTime.noGi = noGi
        newMatTime.openMat = openMat
        newMatTime.restrictions = restrictions
        newMatTime.restrictionDescription = restrictionDescription
        newMatTime.goodForBeginners = goodForBeginners
        newMatTime.adult = adult

        saveChanges()
    }

    // MARK: - Function to save changes to Core Data

    private func saveChanges() {
        do {
            try context.save()
        } catch {
            // Handle the error, perhaps with a logging mechanism
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    func updateSaveEnabled() {
        self.saveEnabled = validateFields()
    }

    
}
