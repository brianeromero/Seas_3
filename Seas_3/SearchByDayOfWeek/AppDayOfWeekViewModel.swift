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
        guard selectedIsland != nil else {
            print("Error: Selected island is nil.")
            return
        }
        
        for day in selectedDays {
            saveDayDetails(for: day)
        }
        
        // Optionally, you can clear selected days or perform any other necessary cleanup
        selectedDays.removeAll()
    }
    
    func saveDayDetails(for day: DayOfWeek) {
        guard let pIsland = selectedIsland else { return }

        let dayEntity = fetchOrCreateAppDayOfWeek(for: pIsland, day: day)

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
        guard let pIsland = selectedIsland else { return }
        
        let dayEntity = fetchOrCreateAppDayOfWeek(for: pIsland, day: day)
        
        matTimeForDay[day] = dayEntity.matTime
        goodForBeginnersForDay[day] = dayEntity.goodForBeginners
        giForDay[day] = dayEntity.gi
        noGiForDay[day] = dayEntity.noGi
        openMatForDay[day] = dayEntity.openMat
        restrictionsForDay[day] = dayEntity.restrictions
        restrictionDescriptionForDay[day] = dayEntity.restrictionDescription
        
        let daySchedules = persistence.fetchAppDayOfWeek(for: pIsland, day: day)
        schedules[day] = daySchedules
    }
    
    func fetchCurrentDayOfWeek() {
        guard let pIsland = selectedIsland else {
            print("Error: Selected island is nil.")
            return
        }
        
        if let currentDayOfWeeks = persistence.fetchAppDayOfWeek(for: pIsland, day: .monday).first {
            // Assuming fetchDayOfWeek(for:) returns an array of AppDayOfWeek objects
            
            // Update properties from the first fetched day
            updateProperties(from: currentDayOfWeeks, day: .monday)
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
        
        // Update selected days based on fetched data
        selectedDays.insert(day) // Assuming selectedDays is a Set<DayOfWeek>
        
        // Debug statement
        print("Properties updated for \(day.displayName) successfully.")
    }
    
    func saveDayOfWeek() {
        guard let selectedIsland = selectedIsland else {
            print("Error: Selected island is nil.")
            return
        }
        
        // Fetch the AppDayOfWeek object for the selected island and DayOfWeek.monday
        let fetchedDayOfWeek = repository.fetchAppDayOfWeek(for: selectedIsland, day: .monday)
        
        // Ensure there's exactly one AppDayOfWeek object matching the criteria
        guard let currentDayOfWeek = fetchedDayOfWeek.first else {
            print("Error: No AppDayOfWeek found for the selected island and Monday.")
            return
        }
        
        // Update the properties of the currentDayOfWeek object
        currentDayOfWeek.matTime = matTime
        currentDayOfWeek.restrictions = restrictions
        currentDayOfWeek.restrictionDescription = restrictions ? restrictionDescription : ""
        currentDayOfWeek.goodForBeginners = goodForBeginners
        currentDayOfWeek.gi = gi
        currentDayOfWeek.noGi = noGi
        currentDayOfWeek.openMat = openMat
        
        // Update the selected days
        for day in DayOfWeek.allCases {
            currentDayOfWeek.setSelected(day: day, selected: selectedDays.contains(day))
        }
        
        // Save the context
        repository.saveContext()
    }

    
    // MARK: - Methods for managing multiple schedules per day
    
    func getSchedules(for day: DayOfWeek) -> [AppDayOfWeek] {
        return schedules[day] ?? []
    }
    
    func addSchedule(for day: DayOfWeek) {
        guard let island = selectedIsland else { return }
        
        let newSchedule = AppDayOfWeek(context: persistence.container.viewContext)
        newSchedule.pIsland = island
        newSchedule.name = day.displayName // Assuming name is used to identify the day
        
        // Set other properties as needed
        schedules[day, default: []].append(newSchedule)
        repository.saveContext()
    }
    
    func deleteSchedule(at offsets: IndexSet, for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else { return }
        
        repository.deleteSchedule(at: offsets, for: day, island: selectedIsland)
    }
    
    func createExampleSchedules() {
        guard let pIsland = persistence.fetchLastPirateIsland() else {
            print("Error: No pirate island found.")
            return
        }

        // Example schedules
        _ = persistence.createAppDayOfWeek(
            pIsland: pIsland,
            dayOfWeek: .monday,
            matTime: "10:00 AM",  // Ensure this matches the optional String? parameter
            gi: true,             // Boolean parameters follow after matTime
            noGi: false,
            openMat: true,
            restrictions: false,
            restrictionDescription: nil  // Optional String parameter
        )

        _ = persistence.createAppDayOfWeek(
            pIsland: pIsland,
            dayOfWeek: .tuesday,
            matTime: "12:00 PM",
            gi: false,
            noGi: true,
            openMat: true,
            restrictions: false,
            restrictionDescription: nil
        )

        _ = persistence.createAppDayOfWeek(
            pIsland: pIsland,
            dayOfWeek: .wednesday,
            matTime: "05:00 PM",
            gi: true,
            noGi: false,
            openMat: false,
            restrictions: true,
            restrictionDescription: "Advanced students only."
        )
    }

    
    // MARK: - Private methods
    
    private func fetchOrCreateAppDayOfWeek(for pIsland: PirateIsland, day: DayOfWeek) -> AppDayOfWeek {
        if let existingDay = persistence.fetchAppDayOfWeek(for: pIsland, day: day).first {
            return existingDay
        } else {
            let newDay = AppDayOfWeek(context: persistence.container.viewContext)
            newDay.pIsland = pIsland
            newDay.name = day.displayName // Assuming name is used to identify the day
            persistence.saveContext()
            return newDay
        }
    }
}
