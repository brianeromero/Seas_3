import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation
import os

enum PirateIslandError: Error {
    case invalidInput
    case islandExists
    case geocodingError(String) // Now includes error message for better detail
    case savingError
    
    var localizedDescription: String {
        switch self {
        case .invalidInput:
            return "Invalid input"
        case .islandExists:
            return "Island already exists"
        case .geocodingError(let message):
            return "Geocoding error: \(message)"
        case .savingError:
            return "Saving error"
        }
    }
}

public class PirateIslandViewModel: ObservableObject {
    @Published var selectedDestination: IslandDestination?
    let logger = OSLog(subsystem: "Seas3.Subsystem", category: "CoreData")
    
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    private func geocodeAddress(_ location: String) async throws -> (latitude: Double, longitude: Double) {
        try await geocode(address: location, apiKey: GeocodingConfig.apiKey)
    }
    
    // MARK: - Island Creation (Original)
    func createPirateIsland(
        name: String,
        location: String,
        createdByUserId: String,
        gymWebsiteURL: URL?,
        completion: @escaping (Result<PirateIsland, Error>) -> Void
    ) async {
        guard validateIslandData(name, location, createdByUserId) else {
            completion(.failure(PirateIslandError.invalidInput))
            return
        }
        
        guard !pirateIslandExists(name: name) else {
            completion(.failure(PirateIslandError.islandExists))
            return
        }
        
        let newIsland = PirateIsland(context: persistenceController.viewContext)
        newIsland.islandName = name
        newIsland.islandLocation = location
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = createdByUserId
        newIsland.lastModifiedByUserId = createdByUserId
        newIsland.lastModifiedTimestamp = Date()
        newIsland.gymWebsite = gymWebsiteURL
        newIsland.islandID = UUID()
        
        do {
            let coordinates = try await geocodeAddress(location)
            newIsland.latitude = coordinates.latitude
            newIsland.longitude = coordinates.longitude
            try persistenceController.viewContext.save()
            completion(.success(newIsland))
        } catch let error {
            completion(.failure(handleGeocodingError(error)))
        }
    }
    
    // MARK: - Island Creation (Async)
    func createPirateIslandAsync(
        islandDetails: IslandDetails,
        createdByUserId: String,
        gymWebsiteURL: URL?
    ) async -> Result<PirateIsland, Error> {
        let name = islandDetails.islandName
        let location = "\(islandDetails.street), \(islandDetails.city), \(islandDetails.state) \(islandDetails.zip)"

        // Validate the island data
        guard validateIslandData(name, location, createdByUserId) else {
            return .failure(PirateIslandError.invalidInput)
        }

        // Check if the island already exists
        guard !pirateIslandExists(name: name) else {
            return .failure(PirateIslandError.islandExists)
        }

        // Create a new PirateIsland instance
        let newIsland = PirateIsland(context: persistenceController.viewContext)
        newIsland.islandName = name  // Correctly using islandName from Core Data properties
        newIsland.islandLocation = location
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = createdByUserId
        newIsland.lastModifiedByUserId = createdByUserId
        newIsland.lastModifiedTimestamp = Date()
        newIsland.gymWebsite = gymWebsiteURL
        newIsland.islandID = UUID()

        do {
            // Get the coordinates using the address from IslandDetails, provide a default value if location is nil
            let coordinates = try await geocodeAddress(location.isEmpty ? "Default Address" : location)
            newIsland.latitude = coordinates.latitude
            newIsland.longitude = coordinates.longitude
            
            // Save the new island to Core Data
            try persistenceController.viewContext.save()
            return .success(newIsland)
        } catch {
            return .failure(PirateIslandError.geocodingError(error.localizedDescription))
        }
    }



    func handleGeocodingError(_ error: Error) -> Error {
        if let error = error as? PirateIslandError {
            return error
        } else if let geocodingError = error as? GeocodingError {
            return PirateIslandError.geocodingError(geocodingError.localizedDescription)
        } else {
            return PirateIslandError.savingError
        }
    }

    
    // MARK: - Validation
    public func validateIslandData(_ name: String, _ location: String, _ createdByUserId: String) -> Bool {
        ![name, location, createdByUserId].isEmpty
    }
    
    // MARK: - Saving Island Data
    func saveIslandData(_ name: String, _ street: String, _ city: String, _ state: String, _ zip: String, website: URL?) async throws {
        guard validateIslandData(name, street, city) else {
            throw PirateIslandError.invalidInput
        }
        
        let fetchRequest = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName == %@", name)
        let existingIsland = (try? persistenceController.viewContext.fetch(fetchRequest).first) ?? nil
        var newIsland: PirateIsland? = existingIsland
        
        if let existingIsland = existingIsland {
            existingIsland.islandLocation = "\(street), \(city), \(state) \(zip)"
            existingIsland.gymWebsite = website
        } else {
            newIsland = PirateIsland(context: persistenceController.viewContext)
            newIsland?.islandName = name
            newIsland?.islandLocation = "\(street), \(city), \(state) \(zip)"
            newIsland?.gymWebsite = website
            newIsland?.islandID = UUID()
        }
        
        let location = "\(street), \(city), \(state) \(zip)"
        if let island = existingIsland ?? newIsland {
            try await saveIslandCoordinates(island, location)
        }
        try persistenceController.saveContext()
    }
    
    // MARK: - Helpers
    private func pirateIslandExists(name: String) -> Bool {
        let fetchRequest = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName == %@", name)
        
        os_log("Executing fetch request: %@", log: logger, String(describing: fetchRequest))
        
        do {
            let count = try persistenceController.viewContext.count(for: fetchRequest)
            return count > 0
        } catch {
            os_log("Error counting islands: %@", log: logger, error.localizedDescription)
            return false
        }
    }
    
    func saveIslandCoordinates(_ island: PirateIsland, _ location: String) async throws {
        do {
            let coordinates = try await geocodeAddress(location)
            island.latitude = coordinates.latitude
            island.longitude = coordinates.longitude
        } catch {
            print("Geocoding failed for \(location): \(error.localizedDescription)")
            island.latitude = 0.0
            island.longitude = 0.0 // Default location in case of failure
        }
    }
    
    func updatePirateIsland(
        island: PirateIsland,
        name: String,
        location: String,
        lastModifiedByUserId: String,
        gymWebsiteURL: URL?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) async {
        guard !name.isEmpty, !location.isEmpty, !lastModifiedByUserId.isEmpty else {
            completion(.failure(PirateIslandError.invalidInput))
            return
        }
        
        guard island.managedObjectContext != nil else {
            completion(.failure(PirateIslandError.invalidInput))
            return
        }
        
        island.islandName = name
        island.islandLocation = location
        island.lastModifiedByUserId = lastModifiedByUserId
        island.gymWebsite = gymWebsiteURL
        island.lastModifiedTimestamp = Date()

        Task {
            do {
                let coordinates = try await geocodeAddress(location)
                island.latitude = coordinates.latitude
                island.longitude = coordinates.longitude
                try persistenceController.saveContext()
                completion(.success(()))
            } catch {
                completion(.failure(PirateIslandError.geocodingError(error.localizedDescription)))
            }
        }
    }
    
    // Make sure this method is async and properly handles the result
    func updatePirateIslandLatitudeLongitude(
        latitude: Double,
        longitude: Double,
        island: PirateIsland
    ) async throws {
        guard island.managedObjectContext != nil else {
            throw PirateIslandError.invalidInput
        }

        island.latitude = latitude
        island.longitude = longitude

        do {
            // If saveContext is synchronous, remove 'await' here
            try persistenceController.saveContext()
        } catch {
            throw PirateIslandError.savingError
        }
    }
}

extension PirateIsland {
    var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
