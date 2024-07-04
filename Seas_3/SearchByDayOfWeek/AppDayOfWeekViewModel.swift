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
    private let persistence = PersistenceController.shared // Reference to PersistenceController
    
    // Published properties for each day of the week
    @Published var matTimeForDay: [DayOfWeek: String] = [:]
    @Published var selectedTimeForDay: [DayOfWeek: Date] = [:]
    @Published var goodForBeginnersForDay: [DayOfWeek: Bool] = [:]
    @Published var giForDay: [DayOfWeek: Bool] = [:]
    @Published var noGiForDay: [DayOfWeek: Bool] = [:]
    @Published var openMatForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionsForDay: [DayOfWeek: Bool] = [:]
    @Published var restrictionDescriptionForDay: [DayOfWeek: String] = [:]
    @Published var openMat: Bool = false
    @Published var matTime: String = ""
    @Published var gi: Bool = false
    @Published var noGi: Bool = false
    @Published var goodForBeginners: Bool = false
    @Published var restrictions: Bool = false
    @Published var restrictionDescription: String = ""
    
    // Set to track selected days with schedules
    @Published var selectedDays: Set<DayOfWeek> = []
    @Published var daysOfWeek: [DayOfWeek] = []
    
    private var selectedIsland: PirateIsland? // Store selected island here
    private let repository: AppDayOfWeekRepository // Reference to Repository
    
    // Dictionary to store schedules for each day
    @Published var schedules: [DayOfWeek: [AppDayOfWeek]] = [:]

    init(selectedIsland: PirateIsland?, repository: AppDayOfWeekRepository = AppDayOfWeekRepository.shared) {
        self.selectedIsland = selectedIsland
        self.repository = repository // Initialize repository
        
        // Initialize arrays/maps based on all cases of DayOfWeek
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
        return !matTime.isEmpty && !selectedDays.isEmpty
        // Add more conditions as needed
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
        guard let selectedIsland = selectedIsland else {
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

        let dayEntity = fetchOrCreateAppDayOfWeek(for: selectedIsland, day: day)

        dayEntity.matTime = matTimeForDay[day] ?? ""
        dayEntity.goodForBeginners = goodForBeginnersForDay[day] ?? false
        dayEntity.gi = giForDay[day] ?? false
        dayEntity.noGi = noGiForDay[day] ?? false
        dayEntity.openMat = openMatForDay[day] ?? false
        dayEntity.restrictions = restrictionsForDay[day] ?? false
        dayEntity.restrictionDescription = restrictionDescriptionForDay[day] ?? ""

        repository.saveContext()
    }

    func fetchDayDetails(for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else { return }

        let dayEntity = fetchOrCreateAppDayOfWeek(for: selectedIsland, day: day)

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
            // Optionally handle what to do if fetch fails or no current day found
        }
    }
    
    private func updateProperties(from dayOfWeek: AppDayOfWeek, day: DayOfWeek) {
        matTimeForDay[day] = dayOfWeek.matTime ?? ""
        restrictionsForDay[day] = dayOfWeek.restrictions
        restrictionDescriptionForDay[day] = dayOfWeek.restrictionDescription ?? ""
        goodForBeginnersForDay[day] = dayOfWeek.goodForBeginners
        giForDay[day] = dayOfWeek.gi
        noGiForDay[day] = dayOfWeek.noGi
        openMatForDay[day] = dayOfWeek.openMat
        
        selectedDays.insert(day)
        
        print("Properties updated for \(day.displayName) successfully.")
    }
    
    func saveDayOfWeek() {
        guard let selectedIsland = selectedIsland else {
            print("Error: Selected island is nil.")
            return
        }
        
        let fetchedDayOfWeek = repository.fetchAppDayOfWeek(for: selectedIsland, day: .monday)
        
        guard let currentDayOfWeek = fetchedDayOfWeek.first else {
            print("Error: No AppDayOfWeek found for the selected island and Monday.")
            return
        }
        
        currentDayOfWeek.matTime = matTime
        currentDayOfWeek.restrictions = restrictions
        currentDayOfWeek.restrictionDescription = restrictions ? restrictionDescription : ""
        currentDayOfWeek.goodForBeginners = goodForBeginners
        currentDayOfWeek.gi = gi
        currentDayOfWeek.noGi = noGi
        currentDayOfWeek.openMat = openMat
        
        for day in DayOfWeek.allCases {
            currentDayOfWeek.setSelected(day: day, selected: selectedDays.contains(day))
        }
        
        repository.saveContext()
    }

    func getSchedules(for day: DayOfWeek) -> [AppDayOfWeek] {
        return schedules[day] ?? []
    }

    func addSchedule(for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else {
            print("Error: No island selected.")
            return
        }
        
        let newSchedule = AppDayOfWeek(context: persistence.container.viewContext)
        newSchedule.pIsland = selectedIsland
        newSchedule.name = day.displayName
        
        let someValidMatTime = "10:00 AM" // Replace with your logic to determine matTime
        newSchedule.matTime = someValidMatTime
        
        do {
            try persistence.container.viewContext.save()
            print("Schedule added successfully.")
        } catch {
            print("Failed to add schedule: \(error)")
        }
    }
    
    func deleteSchedule(at offsets: IndexSet, for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else { return }
        
        repository.deleteSchedule(at: offsets, for: day, island: selectedIsland)
    }

    private func fetchOrCreateAppDayOfWeek(for selectedIsland: PirateIsland, day: DayOfWeek) -> AppDayOfWeek {
        if let existingDay = persistence.fetchAppDayOfWeek(for: selectedIsland, day: day).first {
            return existingDay
        } else {
            let newDay = AppDayOfWeek(context: persistence.container.viewContext)
            newDay.pIsland = selectedIsland
            newDay.name = day.displayName
            persistence.saveContext()
            return newDay
        }
    }
}
