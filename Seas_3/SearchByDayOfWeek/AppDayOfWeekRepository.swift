// AppDayOfWeekRepository.swift
// Seas_3
//
// Created by Brian Romero on 6/25/24.


import Foundation
import SwiftUI
import CoreData
import CoreLocation


class AppDayOfWeekRepository {
    @State private var errorMessage: String?
    let persistenceController: PersistenceController
    private var currentAppDayOfWeek: AppDayOfWeek?
    private var selectedIsland: PirateIsland?

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        print("AppDayOfWeekRepository initialized")
    }
    
    
    public func getViewContext() -> NSManagedObjectContext {
        return persistenceController.viewContext
    }

    static let shared: AppDayOfWeekRepository = {
        let persistence = PersistenceController.shared
        return AppDayOfWeekRepository(persistenceController: persistence)
    }()

    func setSelectedIsland(_ island: PirateIsland) {
        self.selectedIsland = island
    }

    func setCurrentAppDayOfWeek(_ appDayOfWeek: AppDayOfWeek) {
        self.currentAppDayOfWeek = appDayOfWeek
    }

    func performActionThatDependsOnIslandAndDay() {
        guard let island = selectedIsland, let appDay = currentAppDayOfWeek else {
            print("Selected gym or current day of week is not set.")
            return
        }

        guard let dayString = appDay.day, let day = DayOfWeek(rawValue: dayString) else {
            print("Invalid day of week.")
            return
        }

        let context = persistenceController.viewContext

        // Fetch or create the AppDayOfWeek using the updated method
        _ = getAppDayOfWeek(for: day.rawValue, pirateIsland: island, context: context)

        // Perform any additional actions with the fetched AppDayOfWeek if needed
    }
    
    
    func fetchRequest(for day: String) -> NSFetchRequest<AppDayOfWeek> {
        let request: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day)
        return request
    }

    func saveData() {
        print("AppDayOfWeekRepository - Saving data")
        do {
            try persistenceController.saveContext()
        } catch {
            print("Error saving data: \(error)")
        }
    }

    func generateName(for island: PirateIsland, day: DayOfWeek) -> String {
        return "\(String(describing: island.islandName)) \(day.displayName)"
    }
    
    func generateAppDayOfWeekID(for island: PirateIsland, day: DayOfWeek) -> String {
        return "\(String(describing: island.islandName))-\(day.rawValue)"
    }

    func getAppDayOfWeek(for day: String, pirateIsland: PirateIsland, context: NSManagedObjectContext) -> AppDayOfWeek? {
        return fetchOrCreateAppDayOfWeek(for: day, pirateIsland: pirateIsland, context: context)
    }


    func updateAppDayOfWeekName(_ appDayOfWeek: AppDayOfWeek, with island: PirateIsland, dayOfWeek: DayOfWeek, context: NSManagedObjectContext) {
        appDayOfWeek.name = generateName(for: island, day: dayOfWeek)
        appDayOfWeek.appDayOfWeekID = generateAppDayOfWeekID(for: island, day: dayOfWeek)
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    func updateAppDayOfWeek(_ appDayOfWeek: AppDayOfWeek?, with island: PirateIsland, dayOfWeek: DayOfWeek, context: NSManagedObjectContext) {
        if let unwrappedAppDayOfWeek = appDayOfWeek {
            updateAppDayOfWeekName(unwrappedAppDayOfWeek, with: island, dayOfWeek: dayOfWeek, context: context)
        } else {
            // Handle the case where appDayOfWeek is nil
            print("AppDayOfWeek is nil")
        }
    }


    func fetchAllAppDayOfWeeks() -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching all AppDayOfWeeks")
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        return performFetch(request: fetchRequest)
    }

    func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek, context: NSManagedObjectContext) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching AppDayOfWeek: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchOrCreateAppDayOfWeek(for day: String, pirateIsland: PirateIsland, context: NSManagedObjectContext) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day == %@ AND pIsland == %@", day, pirateIsland)

        do {
            let appDayOfWeeks = try context.fetch(fetchRequest)
            if let appDayOfWeek = appDayOfWeeks.first {
                return appDayOfWeek
            } else {
                let newAppDayOfWeek = AppDayOfWeek(context: context)
                newAppDayOfWeek.day = day
                newAppDayOfWeek.pIsland = pirateIsland
                
                // Set the appDayOfWeekID and name using the provided methods
                if let dayOfWeek = DayOfWeek(rawValue: day) {
                    newAppDayOfWeek.appDayOfWeekID = generateAppDayOfWeekID(for: pirateIsland, day: dayOfWeek)
                    newAppDayOfWeek.name = generateName(for: pirateIsland, day: dayOfWeek)
                }

                newAppDayOfWeek.createdTimestamp = Date()
                newAppDayOfWeek.matTimes = nil // Add this line
                return newAppDayOfWeek
            }
        } catch {
            fatalError("Failed to fetch or create AppDayOfWeek: \(error)")
        }
    }

    func addNewAppDayOfWeek(for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else {
            print("Error: selected gym is nil")
            return
        }

        let context = persistenceController.viewContext

        // Fetch or create the AppDayOfWeek using the updated method
        let newAppDayOfWeek = fetchOrCreateAppDayOfWeek(for: day.rawValue, pirateIsland: selectedIsland, context: context)
        currentAppDayOfWeek = newAppDayOfWeek
        
        print("Created or fetched AppDayOfWeek: \(String(describing: newAppDayOfWeek))")
    }


    func deleteSchedule(at indexSet: IndexSet, for day: DayOfWeek, island: PirateIsland) {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)

        do {
            let results = try persistenceController.viewContext.fetch(fetchRequest)
            for index in indexSet {
                let dayToDelete = results[index]
                if let matTimes = dayToDelete.matTimes as? Set<MatTime> {
                    for matTime in matTimes {
                        persistenceController.viewContext.delete(matTime)
                    }
                }
                persistenceController.viewContext.delete(dayToDelete)
            }
            saveData()
        } catch {
            print("Error deleting schedule: \(error.localizedDescription)")
        }
    }

    func fetchSchedules(for island: PirateIsland) -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(String(describing: island.islandName))")
        let predicate = NSPredicate(format: "pIsland == %@", island)
        return persistenceController.fetchSchedules(for: predicate)
    }

    func fetchSchedules(for island: PirateIsland, day: DayOfWeek) -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(String(describing: island.islandName)) and day: \(day.displayName)")
        let predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        return persistenceController.fetchSchedules(for: predicate)
    }

    
    
    
    func deleteRecord(for appDayOfWeek: AppDayOfWeek) {
        print("AppDayOfWeekRepository - Deleting record for AppDayOfWeek: \(appDayOfWeek.appDayOfWeekID ?? "Unknown")")
        if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
            for matTime in matTimes {
                persistenceController.viewContext.delete(matTime)
            }
        }
        persistenceController.viewContext.delete(appDayOfWeek)
        saveData()
    }
    private func performFetch(request: NSFetchRequest<AppDayOfWeek>) -> [AppDayOfWeek] {
        do {
            let results = try persistenceController.viewContext.fetch(request)
            print("Fetch successful: \(results.count) AppDayOfWeek objects fetched.")
            return results
        } catch {
            print("Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    public func fetchGyms(day: String, radius: Double, locationManager: UserLocationMapViewModel) -> [Gym] {
        var fetchedGyms: [Gym] = []

        guard let userLocation = locationManager.getCurrentUserLocation() else {
            print("Failed to get current user location.")
            return fetchedGyms
        }

        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day BEGINSWITH[c] %@", day.lowercased())
        fetchRequest.relationshipKeyPathsForPrefetching = ["pIsland"]

        do {
            let appDayOfWeeks = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)

            for appDayOfWeek in appDayOfWeeks {
                guard let island = appDayOfWeek.pIsland else { continue }

                let distance = locationManager.calculateDistance(from: userLocation, to: CLLocation(latitude: island.latitude, longitude: island.longitude))
                print("Distance to Island: \(distance)")

                let hasScheduledMatTime = appDayOfWeek.matTimes?.count ?? 0 > 0
                fetchedGyms.append(
                    Gym(
                        id: island.islandID ?? UUID(),
                        name: island.islandName ?? "Unnamed Gym",
                        latitude: island.latitude,
                        longitude: island.longitude,
                        hasScheduledMatTime: hasScheduledMatTime,
                        days: [appDayOfWeek.day ?? "Unknown Day"]
                    )
                )
            }
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error)")
        }

        return fetchedGyms
    }
    
    func fetchGyms(day: DayOfWeek?, radius: Double, locationManager: UserLocationMapViewModel) -> [Gym] {
        guard let day = day else {
            print("Day is nil")
            return []
        }
        
        var fetchedGyms: [Gym] = []
        
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day ==[c] %@", day.rawValue)
        fetchRequest.relationshipKeyPathsForPrefetching = ["pIsland", "matTimes"]
        
        do {
            let appDayOfWeeks = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            print("Fetched \(appDayOfWeeks.count) AppDayOfWeek objects")
            
            for appDayOfWeek in appDayOfWeeks {
                guard let island = appDayOfWeek.pIsland else { continue }
                guard let appDay = appDayOfWeek.day, appDay.lowercased() == day.displayName.lowercased() else { continue }
                guard appDayOfWeek.matTimes?.count ?? 0 > 0 else { continue }
                
                /*let distance = locationManager.userLocation.map {
                    locationManager.calculateDistance(from: $0, to: CLLocation(latitude: island.latitude, longitude: island.longitude))
                } ?? 0
                print("Distance to Island: \(distance)")*/
                
                fetchedGyms.append(
                    Gym(
                        id: island.islandID ?? UUID(),
                        name: island.islandName ?? "Unnamed Gym",
                        latitude: island.latitude,
                        longitude: island.longitude,
                        hasScheduledMatTime: true,
                        days: [appDayOfWeek.day ?? "Unknown Day"]
                    )
                )
            }
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error.localizedDescription)")
            errorMessage = "Error fetching gyms: \(error.localizedDescription)"
        }
        
        print("Fetched \(fetchedGyms.count) gyms")
        return fetchedGyms
    }
    
    
    func fetchAllIslands(forDay day: String) async -> [(PirateIsland, [MatTime])] {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "day ==[c] %@", day)

        do {
            let appDayOfWeeks = try context.fetch(fetchRequest)
            var result: [(PirateIsland, [MatTime])] = []

            for appDayOfWeek in appDayOfWeeks {
                if let island = appDayOfWeek.pIsland, let matTimes = appDayOfWeek.matTimes?.allObjects as? [MatTime] {
                    result.append((island, matTimes))
                }
            }

            return result
        } catch {
            print("Error fetching islands: \(error)")
            return []
        }
    }


}
