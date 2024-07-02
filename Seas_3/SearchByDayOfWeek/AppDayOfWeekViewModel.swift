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
    @Published var matTime: String = ""
    @Published var gi: Bool = false
    @Published var noGi: Bool = false
    @Published var goodForBeginners: Bool = false
    @Published var restrictions: Bool = false
    @Published var restrictionDescription: String = ""
    
    @Published var selectedDays: Set<DayOfWeek> = []
    @Published var daysOfWeek: [DayOfWeek] = []

    private let persistenceController: PersistenceController // Reference to PersistenceController
    
    init() {
        self.persistenceController = PersistenceController.shared // Initialize persistenceController
        
        // Fetch or create a new instance of AppDayOfWeek
        if let currentDayOfWeek = fetchDayOfWeek() {
            updateProperties(from: currentDayOfWeek)
        } else {
            createNewDayOfWeek()
        }
    }
    
    var isFormValid: Bool {
        !matTime.isEmpty
    }
    
    func binding(for day: DayOfWeek) -> Binding<Bool> {
        Binding(
            get: {
                self.selectedDays.contains(day)
            },
            set: { newValue in
                if newValue {
                    self.selectedDays.insert(day)
                } else {
                    self.selectedDays.remove(day)
                }
            }
        )
    }
    
    func validateTime() {
        // Your time validation logic here
    }
    
    func fetchCurrentDayOfWeek() {
        guard let currentDayOfWeek = fetchDayOfWeek() else {
            print("Error: Current day of week is nil.")
            return
        }
        updateProperties(from: currentDayOfWeek)
    }
    
    private func fetchDayOfWeek() -> AppDayOfWeek? {
        let context = persistenceController.viewContext
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        
        do {
            let results = try context.fetch(fetchRequest)
            print("Fetched \(results.count) AppDayOfWeek objects.")
            return results.first // Assuming there's only one instance
        } catch {
            print("Error fetching current day of week: \(error)")
            return nil
        }
    }
    
    private func createNewDayOfWeek() {
        let newDayOfWeek = AppDayOfWeek(context: persistenceController.viewContext)
        newDayOfWeek.matTime = "" // Set default values as needed
        newDayOfWeek.restrictions = false
        newDayOfWeek.restrictionDescription = ""
        newDayOfWeek.goodForBeginners = false
        newDayOfWeek.gi = false
        newDayOfWeek.noGi = false
        
        // Set initial values for selected days
        selectedDays = Set(DayOfWeek.allCases)
        
        // Save the newly created instance
        saveDayOfWeek(newDayOfWeek)
    }
    
    private func updateProperties(from dayOfWeek: AppDayOfWeek) {
        matTime = dayOfWeek.matTime ?? ""
        restrictions = dayOfWeek.restrictions
        restrictionDescription = dayOfWeek.restrictionDescription ?? ""
        goodForBeginners = dayOfWeek.goodForBeginners
        gi = dayOfWeek.gi
        noGi = dayOfWeek.noGi
        
        // Update selected days based on fetched data
        selectedDays = Set(DayOfWeek.allCases.filter { dayOfWeek.isSelected(for: $0) })
        
        // Debug statement
        print("Current day of week fetched successfully.")
    }
    
    func saveDayOfWeek() {
        guard let currentDayOfWeek = fetchDayOfWeek() else {
            print("Error: Current day of week is nil.")
            return
        }
        
        currentDayOfWeek.matTime = matTime
        currentDayOfWeek.restrictions = restrictions
        currentDayOfWeek.restrictionDescription = restrictions ? restrictionDescription : ""
        currentDayOfWeek.goodForBeginners = goodForBeginners
        currentDayOfWeek.gi = gi
        currentDayOfWeek.noGi = noGi
        
        // Update the selected days
        for day in DayOfWeek.allCases {
            currentDayOfWeek.setSelected(day: day, selected: selectedDays.contains(day))
        }
        
        // Save the context
        saveDayOfWeek(currentDayOfWeek)
    }
    
    private func saveDayOfWeek(_ dayOfWeek: AppDayOfWeek) {
        let context = persistenceController.viewContext
        do {
            try context.save()
            print("Day of week saved successfully.")
        } catch {
            print("Error saving day of week: \(error)")
        }
    }
}
