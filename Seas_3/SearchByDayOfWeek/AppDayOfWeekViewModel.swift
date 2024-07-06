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
    private let persistence = PersistenceController.shared

    // Published properties for each day of the week
    @Published var matTimeForDay: [DayOfWeek: String] = [:]
    @Published var selectedTimeForDay: [DayOfWeek: Date] = [:]
    @Published var goodForBeginnersForDay: [DayOfWeek: Bool] = [:]
    @Published var giForDay: [DayOfWeek: Bool] = [:]
    @Published var noGiForDay: [DayOfWeek: Bool] = [:]
    @Published var openMatForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionsForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionDescriptionForDay: [DayOfWeek: String] = [:]
    
    // Single properties to hold data for the current form submission
    @Published var goodForBeginners: Bool = false
    @Published var matTime: String?
    @Published var openMat: Bool = false
    @Published var gi: Bool = false
    @Published var noGi: Bool = false
    @Published var restrictions: Bool = false
    @Published var restrictionDescription: String?
    @Published var name: String?
    @Published var day: String?

    // Set to track selected days with schedules
    @Published var selectedDays: Set<DayOfWeek> = []
    @Published var daysOfWeek: [DayOfWeek] = []

    @Published var selectedIsland: PirateIsland?
    private let repository: AppDayOfWeekRepository

    @Published var schedules: [DayOfWeek: [AppDayOfWeek]] = [:]

    init(selectedIsland: PirateIsland?, repository: AppDayOfWeekRepository = AppDayOfWeekRepository.shared) {
        self.selectedIsland = selectedIsland
        self.repository = repository
        
        DayOfWeek.allCases.forEach { day in
            matTimeForDay[day] = ""
            selectedTimeForDay[day] = Date()
            goodForBeginnersForDay[day] = false
            giForDay[day] = false
            noGiForDay[day] = false
            openMatForDay[day] = false
            restrictionsForDay[day] = false
            restrictionDescriptionForDay[day] = ""
            schedules[day] = []
        }

        setupDaysOfWeek()
        fetchCurrentDayOfWeek()
    }

    var isFormValid: Bool {
        return (matTime?.isEmpty == false) && !selectedDays.isEmpty
    }


    func binding(for day: DayOfWeek) -> Binding<Bool> {
        Binding(
            get: { self.selectedDays.contains(day) },
            set: { newValue in
                if newValue {
                    self.selectedDays.insert(day)
                } else {
                    self.selectedDays.remove(day)
                }
            }
        )
    }

    func setupDaysOfWeek() {
        daysOfWeek = DayOfWeek.allCases
    }

    func saveAllSchedules() {
        guard selectedIsland != nil else {
            print("Error: Selected island is nil.")
            return
        }

        for day in selectedDays {
            saveDayDetails(for: day)
        }

        selectedDays.removeAll()
    }

    func saveDayDetails(for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else { return }

        let dayEntity = persistence.fetchOrCreateAppDayOfWeek(for: selectedIsland, day: day)

        dayEntity.matTime = matTimeForDay[day] ?? ""
        dayEntity.goodForBeginners = goodForBeginnersForDay[day] ?? false
        dayEntity.gi = giForDay[day] ?? false
        dayEntity.noGi = noGiForDay[day] ?? false
        dayEntity.openMat = openMatForDay[day] ?? false
        dayEntity.restrictions = restrictionsForDay[day] ?? false
        dayEntity.restrictionDescription = restrictionDescriptionForDay[day] ?? ""

        persistence.saveContext()
    }

    func fetchDayDetails(for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else { return }

        let dayEntity = persistence.fetchOrCreateAppDayOfWeek(for: selectedIsland, day: day)

        matTimeForDay[day] = dayEntity.matTime
        goodForBeginnersForDay[day] = dayEntity.goodForBeginners
        giForDay[day] = dayEntity.gi
        noGiForDay[day] = dayEntity.noGi
        openMatForDay[day] = dayEntity.openMat
        restrictionsForDay[day] = dayEntity.restrictions
        restrictionDescriptionForDay[day] = dayEntity.restrictionDescription

        let daySchedules = persistence.fetchAppDayOfWeek(for: selectedIsland, day: day)
        schedules[day] = daySchedules
    }

    func fetchCurrentDayOfWeek() {
        guard let selectedIsland = selectedIsland else {
            print("Error: Selected island is nil.")
            return
        }

        if let currentDayOfWeek = persistence.fetchAppDayOfWeek(for: selectedIsland, day: .monday).first {
            updateProperties(from: currentDayOfWeek, day: .monday)
        } else {
            print("Error: Failed to fetch current day of week.")
        }
    }

    private func createDayForIsland(island: PirateIsland, day: DayOfWeek) -> AppDayOfWeek {
        let context = persistence.container.viewContext
        let newDay = AppDayOfWeek(context: context)
        
        newDay.day = day.displayName // default value if displayName is empty
        newDay.pIsland = island
        
        if day.displayName.isEmpty {
            print("Error: displayName is empty for day \(day)")
        }
        
        return newDay
    }


    func updateProperties(from dayEntity: AppDayOfWeek, day: DayOfWeek) {
        matTimeForDay[day] = dayEntity.matTime
        goodForBeginnersForDay[day] = dayEntity.goodForBeginners
        giForDay[day] = dayEntity.gi
        noGiForDay[day] = dayEntity.noGi
        openMatForDay[day] = dayEntity.openMat
        restrictionsForDay[day] = dayEntity.restrictions
        restrictionDescriptionForDay[day] = dayEntity.restrictionDescription
    }

    func deleteDay(day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else { return }

        repository.deleteSchedule(at: IndexSet(integer: 0), for: day, island: selectedIsland)
        repository.saveContext()

        matTimeForDay[day] = ""
        goodForBeginnersForDay[day] = false
        giForDay[day] = false
        noGiForDay[day] = false
        openMatForDay[day] = false
        restrictionsForDay[day] = false
        restrictionDescriptionForDay[day] = ""

        selectedDays.remove(day)
    }
}
