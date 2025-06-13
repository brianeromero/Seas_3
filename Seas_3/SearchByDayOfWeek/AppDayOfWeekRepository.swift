// AppDayOfWeekRepository.swift
// Seas_3
//
// Created by Brian Romero on 6/25/24.


import Foundation
import SwiftUI
import CoreData
import CoreLocation
import os
import OSLog // Assuming you use OSLog


class AppDayOfWeekRepository: ObservableObject {
    @State private var errorMessage: String?
    private var currentAppDayOfWeek: AppDayOfWeek?
    private var selectedIsland: PirateIsland?
    let logger = OSLog(subsystem: "Seas3.Subsystem", category: "CoreData")
    
    private var persistenceController: PersistenceController
    
    // Custom initializer to accept PersistenceController
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        print("AppDayOfWeekRepository initialized with PersistenceController")
    }
    
    // Access the view context from the passed persistence controller
    public func getViewContext() -> NSManagedObjectContext {
        return persistenceController.viewContext
    }
    
    static let shared: AppDayOfWeekRepository = {
        let persistenceController = PersistenceController.shared
        return AppDayOfWeekRepository(persistenceController: persistenceController)
    }()
    
    func setSelectedIsland(_ island: PirateIsland) {
        self.selectedIsland = island
    }
    
    func setCurrentAppDayOfWeek(_ appDayOfWeek: AppDayOfWeek) {
        self.currentAppDayOfWeek = appDayOfWeek
    }
    
    // Modify other functions to use the shared PersistenceController instance instead of the local persistenceController variable
    func performActionThatDependsOnIslandAndDay() {
        guard let island = selectedIsland, let appDay = currentAppDayOfWeek else {
            print("Selected gym or current day of week is not set.")
            return
        }
        
        if appDay.day.isEmpty {
            print("Invalid day of week.")
            return
        }
        
        guard DayOfWeek(rawValue: appDay.day.lowercased()) != nil else {
            print("Invalid day of week.")
            return
        }
        
        let context = PersistenceController.shared.viewContext
        _ = getAppDayOfWeek(for: appDay.day, pirateIsland: island, context: context)
    }
    
    
    func saveData() async {
        print("AppDayOfWeekRepository - Saving data")
        do {
            try await PersistenceController.shared.saveContext()
        } catch {
            print("Error saving data: \(error)")
        }
    }
    
    func generateName(for island: PirateIsland, day: DayOfWeek) -> String {
        let islandName = island.islandName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Gym"
        let name = "\(islandName) -\(day.rawValue.lowercased())"
        print("Generated name: \(name)")
        return name
    }
    
    
    func generateAppDayOfWeekID(for island: PirateIsland, day: DayOfWeek) -> String {
        return "\(island.islandName ?? "Unknown Gym")-\(day.rawValue)"
    }
    
    
    func getAppDayOfWeek(for day: String, pirateIsland: PirateIsland, context: NSManagedObjectContext) -> AppDayOfWeek? {
        return fetchOrCreateAppDayOfWeek(for: day, pirateIsland: pirateIsland, context: context)
    }
    
    
    func updateAppDayOfWeekName(_ appDayOfWeek: AppDayOfWeek, with island: PirateIsland, dayOfWeek: DayOfWeek, context: NSManagedObjectContext) {
        // ✅ Explicitly update all related fields
        appDayOfWeek.day = dayOfWeek.rawValue
        appDayOfWeek.pIsland = island
        appDayOfWeek.name = generateName(for: island, day: dayOfWeek)
        appDayOfWeek.appDayOfWeekID = generateAppDayOfWeekID(for: island, day: dayOfWeek)
        
        // Optional: safeguard against nil (but generateName should prevent that)
        if appDayOfWeek.name == nil {
            print("⚠️ Warning: AppDayOfWeek name is nil! Setting fallback.")
            appDayOfWeek.name = "Default Name"
        }
        
        // ✅ Save context
        do {
            try context.save()
        } catch {
            print("❌ Failed to save context: \(error)")
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
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "AppDayOfWeek", in: PersistenceController.shared.viewContext)!
        fetchRequest.relationshipKeyPathsForPrefetching = ["matTimes"]
        return performFetch(request: fetchRequest) ?? []
    }
    
    func fetchAppDayOfWeek(for day: String, pirateIsland: PirateIsland, context: NSManagedObjectContext) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "AppDayOfWeek", in: context)!
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", pirateIsland, day)
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
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "AppDayOfWeek", in: context)!
        fetchRequest.predicate = NSPredicate(format: "day == %@ AND pIsland == %@", day, pirateIsland)
        
        do {
            let appDayOfWeeks = try context.fetch(fetchRequest)
            if let appDayOfWeek = appDayOfWeeks.first {
                return appDayOfWeek
            } else {
                let newAppDayOfWeek = AppDayOfWeek(context: context)
                newAppDayOfWeek.day = day
                newAppDayOfWeek.pIsland = pirateIsland
                
                if let dayOfWeek = DayOfWeek(rawValue: day) {
                    newAppDayOfWeek.appDayOfWeekID = generateAppDayOfWeekID(for: pirateIsland, day: dayOfWeek)
                    newAppDayOfWeek.name = generateName(for: pirateIsland, day: dayOfWeek)
                }
                
                newAppDayOfWeek.createdTimestamp = Date()
                newAppDayOfWeek.matTimes = nil
                
                try context.save()
                return newAppDayOfWeek
            }
        } catch {
            print("Error fetching or creating AppDayOfWeek: \(error.localizedDescription)")
            return nil
        }
    }
    
    
    // MARK: - fetchOrCreateAppDayOfWeek AS COMBO OF selectIslandAndDay and fetchCurrentDayOfWeek
    func fetchOrCreateAppDayOfWeek(for day: DayOfWeek, pirateIsland: PirateIsland, context: NSManagedObjectContext) -> AppDayOfWeek? {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "AppDayOfWeek", in: context)!
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", pirateIsland, day.displayName)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingAppDayOfWeek = results.first {
                return existingAppDayOfWeek
            } else {
                let newAppDayOfWeek = AppDayOfWeek(context: context)
                newAppDayOfWeek.pIsland = pirateIsland
                newAppDayOfWeek.day = day.displayName
                
                // Generate name and appDayOfWeekID using your existing methods
                newAppDayOfWeek.name = generateName(for: pirateIsland, day: day) // Assign the generated name
                newAppDayOfWeek.appDayOfWeekID = generateAppDayOfWeekID(for: pirateIsland, day: day) // Assign the generated ID
                
                try context.save()
                return newAppDayOfWeek
            }
        } catch {
            print("Error fetching or creating AppDayOfWeek: \(error.localizedDescription)")
            return nil
        }
    }
    
    
    // MARK:
    func addNewAppDayOfWeek(for day: DayOfWeek) {
        guard let selectedIsland = selectedIsland else {
            print("Error: selected gym is nil")
            return
        }
        
        let context = PersistenceController.shared.viewContext
        
        // Fetch or create the AppDayOfWeek using the updated method
        let newAppDayOfWeek = fetchOrCreateAppDayOfWeek(for: day.rawValue, pirateIsland: selectedIsland, context: context)
        currentAppDayOfWeek = newAppDayOfWeek
        
        print("Created or fetched AppDayOfWeek: \(newAppDayOfWeek.debugDescription)")
    }
    
    func deleteSchedule(at indexSet: IndexSet, for day: DayOfWeek, island: PirateIsland) async {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "AppDayOfWeek", in: PersistenceController.shared.viewContext)!
        fetchRequest.predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        
        do {
            let results = try PersistenceController.shared.viewContext.fetch(fetchRequest)
            for index in indexSet {
                let dayToDelete = results[index]
                if let matTimes = dayToDelete.matTimes as? Set<MatTime> {
                    for matTime in matTimes {
                        PersistenceController.shared.viewContext.delete(matTime)
                    }
                }
                PersistenceController.shared.viewContext.delete(dayToDelete)
            }
            await saveData()
        } catch {
            print("Error deleting schedule: \(error.localizedDescription)")
        }
    }
    
    func fetchSchedules(for island: PirateIsland) async -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(island.islandName ?? "Unknown Gym")")
        let predicate = NSPredicate(format: "pIsland == %@", island)
        do {
            return try await PersistenceController.shared.fetchSchedules(for: predicate)
        } catch {
            print("Error fetching schedules: \(error.localizedDescription)")
            return []
        }
    }
    
    func fetchSchedules(for island: PirateIsland, day: DayOfWeek) async -> [AppDayOfWeek] {
        print("AppDayOfWeekRepository - Fetching schedules for island: \(island.islandName!) and day: \(day.displayName)")
        let predicate = NSPredicate(format: "pIsland == %@ AND day == %@", island, day.rawValue)
        do {
            return try await PersistenceController.shared.fetchSchedules(for: predicate)
        } catch {
            print("Error fetching schedules: \(error.localizedDescription)")
            return []
        }
    }
    
    func deleteRecord(for appDayOfWeek: AppDayOfWeek) async {
        print("AppDayOfWeekRepository - Deleting record for AppDayOfWeek: \(appDayOfWeek.appDayOfWeekID ?? "Unknown")")
        if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
            for matTime in matTimes {
                PersistenceController.shared.viewContext.delete(matTime)
            }
        }
        PersistenceController.shared.viewContext.delete(appDayOfWeek)
        await saveData()
    }
    
    private func performFetch(request: NSFetchRequest<AppDayOfWeek>) -> [AppDayOfWeek]? {
        do {
            let results = try PersistenceController.shared.viewContext.fetch(request)
            print("Fetch successful: \(results.count) AppDayOfWeek objects fetched.")
            return results
        } catch {
            print("Fetch error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func fetchPirateIslands(day: String, radius: Double, locationManager: UserLocationMapViewModel) -> [PirateIsland] {
        var fetchedIslands: [PirateIsland] = []
        
        guard let userLocation = locationManager.getCurrentUserLocation() else {
            print("Failed to get current user location.")
            return fetchedIslands
        }
        
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "AppDayOfWeek", in: PersistenceController.shared.container.viewContext)!
        fetchRequest.predicate = NSPredicate(format: "day BEGINSWITH[c] %@", day.lowercased())
        fetchRequest.relationshipKeyPathsForPrefetching = ["pIsland"]
        
        do {
            let appDayOfWeeks = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            
            for appDayOfWeek in appDayOfWeeks {
                guard let island = appDayOfWeek.pIsland else { continue }
                
                let distance = locationManager.calculateDistance(from: userLocation, to: CLLocation(latitude: island.latitude, longitude: island.longitude))
                print("Distance to Island: \(distance)")
                
                fetchedIslands.append(island)
            }
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error.localizedDescription)")
        }
        
        return fetchedIslands
    }
    
    
    
    func fetchPirateIslands(day: DayOfWeek?, radius: Double, locationManager: UserLocationMapViewModel) -> [PirateIsland] {
        guard let day = day else {
            print("Day is nil")
            return []
        }
        
        var fetchedIslands: [PirateIsland] = []
        
        let fetchRequest = AppDayOfWeek.fetchRequest()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: "AppDayOfWeek", in: PersistenceController.shared.container.viewContext)!
        fetchRequest.predicate = NSPredicate(format: "day ==[c] %@", day.rawValue)
        fetchRequest.relationshipKeyPathsForPrefetching = ["pIsland", "matTimes"]
        
        do {
            let appDayOfWeeks = try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            print("Fetched \(appDayOfWeeks.count) AppDayOfWeek objects")
            
            fetchedIslands = appDayOfWeeks.compactMap { appDayOfWeek in
                guard let island = appDayOfWeek.pIsland,
                      appDayOfWeek.day.lowercased() == day.displayName.lowercased(),
                      appDayOfWeek.matTimes?.count ?? 0 > 0 else { return nil }
                return island
            }
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error.localizedDescription)")
            errorMessage = "Error fetching pirate islands: \(error.localizedDescription)"
        }
        
        print("Fetched \(fetchedIslands.count) pirate islands")
        return fetchedIslands
    }
    
    // MARK: - Updated fetchAllIslands Method
    
    // MARK: - New fetchAllIslands Method
    func fetchAllIslands(forDay day: String) async throws -> [NSManagedObjectID] { // Changed return type!
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "ANY appDayOfWeeks.day == %@", day.lowercased())
        
        // It's still good to prefetch relationships if you intend to access them
        // immediately after rehydration on the main context.
        fetchRequest.relationshipKeyPathsForPrefetching = ["appDayOfWeeks", "appDayOfWeeks.matTimes"]
        
        os_log("Executing fetch request for PirateIslands: %@", log: logger, String(describing: fetchRequest))
        
        return try await backgroundContext.perform {
            let islands = try backgroundContext.fetch(fetchRequest)
            
            let filteredIslands = islands.filter { island in
                guard let appDayOfWeeks = island.appDayOfWeeks as? Set<AppDayOfWeek> else { return false }
                return appDayOfWeeks.contains(where: { appDayOfWeek in
                    guard appDayOfWeek.day.lowercased() == day.lowercased() else { return false }
                    return (appDayOfWeek.matTimes?.count ?? 0) > 0
                })
            }
            
            print("Fetched and filtered islands count in repository: \(filteredIslands.count). Returning ObjectIDs.")
            
            // Do NOT print island properties here, as they are on the background context.
            // for island in filteredIslands {
            //     print("    Repository fetched PirateIsland: \(island.islandName ?? "Unnamed"), Lat: \(island.latitude), Lon: \(island.longitude), ID: \(island.objectID)")
            // }
            
            // ✅ Crucial change: Return objectIDs
            return filteredIslands.map { $0.objectID }
        }
    }
}
