//
//  AppDayOfWeekViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import CoreData
import SwiftUI

class AppDayOfWeekViewModel: ObservableObject {
    @Published var daysOfWeek: [AppDayOfWeek.DayOfWeek]
    @Published private(set) var selectedDays: [Bool]
    @Published var matTime: String = ""
    @Published var restrictions: Bool = false
    @Published var restrictionDescription: String = ""
    @Published var goodForBeginners: Bool = false
    @Published var gi: Bool = false
    @Published var noGi: Bool = false
    @Published var openMat: Bool = false
    @Published private(set) var openMatDays: [Bool]
    
    private let coreDataStack: CoreDataStack

    init() {
        self.selectedDays = Array(repeating: false, count: 7) // Assuming 7 days in a week
        self.openMatDays = Array(repeating: false, count: 7)
        self.coreDataStack = CoreDataStack.shared // Initialize coreDataStack
        self.daysOfWeek = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

        self.fetchCurrentDayOfWeek()
    }

    var isFormValid: Bool {
        // Ensure matTime is not empty
        if matTime.isEmpty {
            return false
        }

        // Ensure restriction description is not empty if restrictions are enabled
        if restrictions && restrictionDescription.isEmpty {
            return false
        }

        return true
    }
    
    var fetchDayOfWeek: AppDayOfWeek? {
        let context = coreDataStack.viewContext // Access context from CoreDataStack.shared
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

    func fetchCurrentDayOfWeek() {
        guard let currentDayOfWeek = fetchDayOfWeek else {
            // If fetchDayOfWeek returns nil, create a new instance
            let newDayOfWeek = AppDayOfWeek(context: coreDataStack.viewContext)
            newDayOfWeek.matTime = "" // Set default values as needed
            newDayOfWeek.restrictions = false
            newDayOfWeek.restrictionDescription = ""
            newDayOfWeek.goodForBeginners = false
            newDayOfWeek.gi = false
            newDayOfWeek.noGi = false
            newDayOfWeek.openMat = false

            // Set initial values for selected days
            for (index, day) in daysOfWeek.enumerated() {
                switch day {
                case .sunday:
                    newDayOfWeek.sunday = false
                    newDayOfWeek.op_sunday = false
                case .monday:
                    newDayOfWeek.monday = false
                    newDayOfWeek.op_monday = false
                case .tuesday:
                    newDayOfWeek.tuesday = false
                    newDayOfWeek.op_tuesday = false
                case .wednesday:
                    newDayOfWeek.wednesday = false
                    newDayOfWeek.op_wednesday = false
                case .thursday:
                    newDayOfWeek.thursday = false
                    newDayOfWeek.op_thursday = false
                case .friday:
                    newDayOfWeek.friday = false
                    newDayOfWeek.op_friday = false
                case .saturday:
                    newDayOfWeek.saturday = false
                    newDayOfWeek.op_saturday = false
                }
                selectedDays[index] = false
                openMatDays[index] = false
            }
            
            self.saveNewDayOfWeek(newDayOfWeek) // Save the newly created instance
            return
        }

        // If an existing entity is fetched, update properties and selected days
        matTime = currentDayOfWeek.matTime ?? ""
        restrictions = currentDayOfWeek.restrictions
        restrictionDescription = currentDayOfWeek.restrictionDescription ?? ""
        goodForBeginners = currentDayOfWeek.goodForBeginners
        gi = currentDayOfWeek.gi
        noGi = currentDayOfWeek.noGi
        openMat = currentDayOfWeek.openMat

        // Update selected days based on fetched data
        for (index, day) in daysOfWeek.enumerated() {
            switch day {
            case .sunday:
                selectedDays[index] = currentDayOfWeek.sunday
                openMatDays[index] = currentDayOfWeek.op_sunday
            case .monday:
                selectedDays[index] = currentDayOfWeek.monday
                openMatDays[index] = currentDayOfWeek.op_monday
            case .tuesday:
                selectedDays[index] = currentDayOfWeek.tuesday
                openMatDays[index] = currentDayOfWeek.op_tuesday
            case .wednesday:
                selectedDays[index] = currentDayOfWeek.wednesday
                openMatDays[index] = currentDayOfWeek.op_wednesday
            case .thursday:
                selectedDays[index] = currentDayOfWeek.thursday
                openMatDays[index] = currentDayOfWeek.op_thursday
            case .friday:
                selectedDays[index] = currentDayOfWeek.friday
                openMatDays[index] = currentDayOfWeek.op_friday
            case .saturday:
                selectedDays[index] = currentDayOfWeek.saturday
                openMatDays[index] = currentDayOfWeek.op_saturday
            }
        }
        
        // Debug statement
        print("Current day of week fetched successfully.")
    }

    func saveDayOfWeek() {
        guard let currentDayOfWeek = fetchDayOfWeek else {
            print("Error: Current day of week is nil.")
            return
        }

        currentDayOfWeek.matTime = matTime
        currentDayOfWeek.restrictions = restrictions
        currentDayOfWeek.restrictionDescription = restrictions ? restrictionDescription : ""
        currentDayOfWeek.goodForBeginners = goodForBeginners
        currentDayOfWeek.gi = gi
        currentDayOfWeek.noGi = noGi
        currentDayOfWeek.openMat = openMat

        // Update individual days of the week based on selectedDays
        for (index, day) in daysOfWeek.enumerated() {
            switch day {
            case .sunday:
                currentDayOfWeek.sunday = selectedDays[index]
                currentDayOfWeek.op_sunday = openMatDays[index]
            case .monday:
                currentDayOfWeek.monday = selectedDays[index]
                currentDayOfWeek.op_monday = openMatDays[index]
            case .tuesday:
                currentDayOfWeek.tuesday = selectedDays[index]
                currentDayOfWeek.op_tuesday = openMatDays[index]
            case .wednesday:
                currentDayOfWeek.wednesday = selectedDays[index]
                currentDayOfWeek.op_wednesday = openMatDays[index]
            case .thursday:
                currentDayOfWeek.thursday = selectedDays[index]
                currentDayOfWeek.op_thursday = openMatDays[index]
            case .friday:
                currentDayOfWeek.friday = selectedDays[index]
                currentDayOfWeek.op_friday = openMatDays[index]
            case .saturday:
                currentDayOfWeek.saturday = selectedDays[index]
                currentDayOfWeek.op_saturday = openMatDays[index]
            }
        }

        do {
            try currentDayOfWeek.managedObjectContext?.save()
            print("Day of week saved successfully.")
        } catch {
            print("Failed to save day of week: \(error)")
        }
    }

    func validateTime() {
        let regex = #"^([01]?[0-9]|2[0-3]):[0-5][0-9]$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        if !predicate.evaluate(with: matTime) {
            matTime = ""
            print("Invalid time format entered.")
        }
    }

    func binding(for day: AppDayOfWeek.DayOfWeek) -> Binding<Bool> {
        let index = daysOfWeek.firstIndex(of: day) ?? 0
        return Binding(
            get: { self.selectedDays[index] },
            set: { newValue in
                self.selectedDays[index] = newValue
                self.saveDayOfWeek()
            }
        )
    }

    func openMatBinding(for day: AppDayOfWeek.DayOfWeek) -> Binding<Bool> {
        let index = daysOfWeek.firstIndex(of: day) ?? 0
        return Binding(
            get: { self.openMatDays[index] },
            set: { newValue in
                self.openMatDays[index] = newValue
                self.saveDayOfWeek()
            }
        )
    }

    private func saveNewDayOfWeek(_ newDayOfWeek: AppDayOfWeek) {
        do {
            try newDayOfWeek.managedObjectContext?.save()
            print("New day of week entity saved successfully.")
        } catch {
            print("Failed to save new day of week entity: \(error)")
        }
    }
}
