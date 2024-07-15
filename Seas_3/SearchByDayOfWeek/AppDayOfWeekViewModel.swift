//
//  AppDayOfWeekViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Combine
import CoreData

class AppDayOfWeekViewModel: ObservableObject {
    private let repository: AppDayOfWeekRepository
    private var cancellables: Set<AnyCancellable> = []

    @Published var appDayOfWeekList: [AppDayOfWeek] = []
    @Published var matTimeForDay: [DayOfWeek: String] = [:]
    @Published var selectedTimeForDay: [DayOfWeek: Date] = [:]
    @Published var goodForBeginnersForDay: [DayOfWeek: Bool] = [:]
    @Published var giForDay: [DayOfWeek: Bool] = [:]
    @Published var noGiForDay: [DayOfWeek: Bool] = [:]
    @Published var openMatForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionsForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionDescriptionForDay: [DayOfWeek: String] = [:]
    @Published var daySettings: [DayOfWeek: Bool] = [:]
    @Published var selectedDays: Set<DayOfWeek> = []
    @Published var schedules: [DayOfWeek: [AppDayOfWeek]] = [:]
    @Published var selectedIsland: PirateIsland?

    @Published var allIslands: [PirateIsland] = []
    @Published var errorMessage: String?

    private let persistenceController = PersistenceController.shared
    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()

    init(selectedIsland: PirateIsland?, repository: AppDayOfWeekRepository = AppDayOfWeekRepository.shared) {
        self.selectedIsland = selectedIsland
        self.repository = repository

        initializeDaySettings()

        if let island = selectedIsland {
            fetchCurrentDayOfWeek() // Fetches AppDayOfWeek items for the selected island upon initialization
            loadSchedules(for: island)
        }
        fetchPirateIslands()
    }

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
        }
    }

    func binding(for day: DayOfWeek) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.daySettings[day] ?? false },
            set: { self.daySettings[day] = $0 }
        )
    }

    func loadSchedules(for island: PirateIsland) {
        DayOfWeek.allCases.forEach { day in
            schedules[day] = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        }
    }

    private func updateSchedules() {
        print("AppDayOfWeekViewModel - Updating schedules")
        guard let island = selectedIsland else { return }
        selectedDays.forEach { day in
            guard let dayEntity = repository.fetchOrCreateAppDayOfWeek(for: island, day: day) else {
                return
            }

            // Ensure matTime is properly formatted
            if let selectedTime = selectedTimeForDay[day] {
                dayEntity.matTime = dateFormatter.string(from: selectedTime)
            }

            // Update other attributes as needed
            dayEntity.goodForBeginners = goodForBeginnersForDay[day] ?? false
            dayEntity.gi = giForDay[day] ?? false
            dayEntity.noGi = noGiForDay[day] ?? false
            dayEntity.openMat = openMatForDay[day] ?? false
            dayEntity.restrictions = restrictionsForDay[day] ?? false
            dayEntity.restrictionDescription = restrictionDescriptionForDay[day]

            repository.saveContext()
        }
    }


    
    
    func clearSelections() {
        print("AppDayOfWeekViewModel - Clearing selections")
        matTimeForDay.forEach { day, _ in
            matTimeForDay[day] = ""
            selectedTimeForDay[day] = Date()
            goodForBeginnersForDay[day] = false
            giForDay[day] = false
            noGiForDay[day] = false
            openMatForDay[day] = false
            restrictionsForDay[day] = false
            restrictionDescriptionForDay[day] = ""
        }
    }


    
    
    func toggleDaySelection(_ day: DayOfWeek) {
        print("AppDayOfWeekViewModel - Toggling selection for day: \(day.displayName)")
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    func isSelected(_ day: DayOfWeek) -> Bool {
        selectedDays.contains(day)
    }

    func fetchSchedules() {
        guard let island = selectedIsland else { return }
        DayOfWeek.allCases.forEach { day in
            schedules[day] = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
        }
    }

    func updateMatTime(for day: DayOfWeek, time: String) {
        print("AppDayOfWeekViewModel - Updating mat time for day \(day.displayName) to \(time)")
        matTimeForDay[day] = time
    }


    func updateSelectedTime(for day: DayOfWeek, time: Date) {
        selectedTimeForDay[day] = time
    }

    func fetchCurrentDayOfWeek() {
        print("AppDayOfWeekViewModel - Fetching current day of week")
        guard let island = selectedIsland else {
            print("selectedIsland is nil")
            return
        }

        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "pIsland == %@", island)

        do {
            appDayOfWeekList = try context.fetch(request)
            print("Fetched \(appDayOfWeekList.count) AppDayOfWeek items for island: \(island.islandName)")
            appDayOfWeekList.forEach {
                print("Day: \($0.day ?? "N/A"), Time: \($0.matTime ?? "N/A"), GI: \($0.gi), NoGi: \($0.noGi)")
            }
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error)")
        }
    }


    func fetchAppDayOfWeekAndUpdateList(for island: PirateIsland, day: DayOfWeek) {
        self.appDayOfWeekList = repository.fetchAppDayOfWeekFromPersistence(for: island, day: day)
    }

    func saveChanges() {
        repository.saveContext()
    }

    func saveAllSchedules() {
        repository.saveContext()
    }

    func deleteSchedule(at offsets: IndexSet, for day: DayOfWeek) {
        guard let island = selectedIsland else {
            print("No selected island to delete schedules from.")
            return
        }
        repository.deleteSchedule(at: offsets, for: day, island: island)
    }



    private func saveContext() {
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    
    func updateSchedulesForSelectedDays() {
        print("AppDayOfWeekViewModel - Updating schedules for selected days")
        // Implement your logic to update schedules for selected days
    }

    func generateNameForDay(_ day: AppDayOfWeek) -> String {
        var nameComponents: [String] = []

        if let matTime = day.matTime {
            nameComponents.append(matTime)
        }

        if day.gi {
            nameComponents.append("gi")
        }
        if day.noGi {
            nameComponents.append("noGi")
        }

        return nameComponents.joined(separator: " ")
    }




    func fetchPirateIslands() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            allIslands = try persistenceController.viewContext.fetch(fetchRequest)
        } catch {
            errorMessage = "Failed to fetch pirate islands: \(error.localizedDescription)"
            print(errorMessage ?? "Unknown error")
        }
    }

    func updateName(for day: AppDayOfWeek) {
        var nameComponents: [String] = []

        if day.gi {
            nameComponents.append("gi")
        }
        if day.noGi {
            nameComponents.append("noGi")
        }
        if let matTime = day.matTime {
            nameComponents.append(matTime)
        }

        day.name = nameComponents.joined(separator: " ")
    }
}
