// AppDayOfWeekViewModel.swift
// Seas_3
// Created by Brian Romero on 6/26/24.

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
    @Published var daySettings: [DayOfWeek: Bool] = [:]

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
        fetchCurrentDayOfWeek()
        
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
        
        if let island = selectedIsland {
            self.loadSchedules(for: island)
        }
    }

    func binding(for day: DayOfWeek) -> Binding<Bool> {
        return Binding<Bool>(
            get: { self.daySettings[day] ?? false },
            set: { self.daySettings[day] = $0 }
        )
    }

    // Function to load schedules for a specific island
    func loadSchedules(for island: PirateIsland) {
        DayOfWeek.allCases.forEach { day in
            schedules[day] = persistence.fetchAppDayOfWeek(for: island, day: day)
        }
    }
    
    // Helper function to save context
    private func saveContext() {
        do {
            try persistence.viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    // Function to update schedules for all selected days
    func updateSchedulesForSelectedDays() {
        guard let island = selectedIsland else { return }
        selectedDays.forEach { day in
            let dayEntity = persistence.fetchOrCreateAppDayOfWeek(for: island, day: day)
            dayEntity.goodForBeginners = goodForBeginnersForDay[day] ?? false
            dayEntity.matTime = matTimeForDay[day]
            dayEntity.gi = giForDay[day] ?? false
            dayEntity.noGi = noGiForDay[day] ?? false
            dayEntity.openMat = openMatForDay[day] ?? false
            dayEntity.restrictions = restrictionsForDay[day] ?? false
            dayEntity.restrictionDescription = restrictionDescriptionForDay[day]

            // Update the selected time if available
            if let selectedTime = selectedTimeForDay[day] {
                let formatter = DateFormatter()
                formatter.dateFormat = "hh:mm a"
                dayEntity.matTime = formatter.string(from: selectedTime)
            }

            saveContext()
        }
    }

    // Function to toggle selection of a day
    func toggleDaySelection(_ day: DayOfWeek) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    // Function to check if a day is selected
    func isSelected(_ day: DayOfWeek) -> Bool {
        selectedDays.contains(day)
    }

    // Function to fetch schedules for a specific day
    func fetchSchedules(for day: DayOfWeek) -> [AppDayOfWeek] {
        schedules[day] ?? []
    }

    // Function to update matTime for a specific day
    func updateMatTime(for day: DayOfWeek, time: String) {
        matTimeForDay[day] = time
    }

    // Function to update selectedTime for a specific day
    func updateSelectedTime(for day: DayOfWeek, time: Date) {
        selectedTimeForDay[day] = time
    }

    func fetchCurrentDayOfWeek() {
        // Fetch logic to populate `daySettings` from Core Data
        Logger.log("Fetching current day settings", view: "AppDayOfWeekViewModel")
    }

    func saveAllSchedules() {
        // Save logic for `daySettings` to Core Data
        Logger.log("Saving all day settings", view: "AppDayOfWeekViewModel")
    }
}
