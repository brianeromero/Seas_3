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
            schedules[day] = repository.fetchAppDayOfWeek(for: island, day: day)
        }
    }

    func updateSchedulesForSelectedDays() {
        guard let island = selectedIsland else { return }
        selectedDays.forEach { day in
            let dayEntity = repository.fetchOrCreateAppDayOfWeek(for: island, day: day)
            dayEntity.goodForBeginners = goodForBeginnersForDay[day] ?? false
            dayEntity.matTime = matTimeForDay[day]
            dayEntity.gi = giForDay[day] ?? false
            dayEntity.noGi = noGiForDay[day] ?? false
            dayEntity.openMat = openMatForDay[day] ?? false
            dayEntity.restrictions = restrictionsForDay[day] ?? false
            dayEntity.restrictionDescription = restrictionDescriptionForDay[day]

            if let selectedTime = selectedTimeForDay[day] {
                dayEntity.matTime = dateFormatter.string(from: selectedTime)
            }

            repository.saveContext()
        }
    }

    func toggleDaySelection(_ day: DayOfWeek) {
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
            schedules[day] = repository.fetchAppDayOfWeek(for: island, day: day)
        }
    }

    func updateMatTime(for day: DayOfWeek, time: String) {
        matTimeForDay[day] = time
    }

    func updateSelectedTime(for day: DayOfWeek, time: Date) {
        selectedTimeForDay[day] = time
    }

    func fetchCurrentDayOfWeek() {
        guard let island = selectedIsland else {
            print("selectedIsland is nil")
            return
        }

        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "pIsland == %@", island)

        do {
            appDayOfWeekList = try context.fetch(request)
            print("Fetched \(appDayOfWeekList.count) AppDayOfWeek items")
            appDayOfWeekList.forEach {
                print("Day: \($0.day ?? "N/A"), Time: \($0.matTime ?? "N/A"), GI: \($0.gi), NoGi: \($0.noGi)")
            }
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error)")
        }
    }


    func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek) {
        self.appDayOfWeekList = repository.fetchAppDayOfWeek(for: island, day: day)
    }

    func saveChanges() {
        repository.saveContext()
    }

    func saveAllSchedules() {
        repository.saveContext()
    }

    func deleteSchedule(at offsets: IndexSet, for day: DayOfWeek, island: PirateIsland) {
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

    func generateNameForDay(_ day: DayOfWeek) -> String {
        return "Name for \(day.displayName)" // Implement your logic here
    }
}
