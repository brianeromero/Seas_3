import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation

enum PirateIslandError: Error {
    case invalidInput
    case islandExists
    case geocodingError
    case savingError
    
    var localizedDescription: String {
        switch self {
        case .invalidInput:
            return "Invalid input"
        case .islandExists:
            return "Island already exists"
        case .geocodingError:
            return "Geocoding error"
        case .savingError:
            return "Saving error"
        }
    }
}

class PirateIslandViewModel: ObservableObject {
    @Published var selectedDestination: IslandDestination?
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    
    private func geocodeAddress(_ location: String) async throws -> (latitude: Double, longitude: Double) {
        try await geocode(address: location, apiKey: GeocodingConfig.apiKey)
    }
    
    // MARK: - Island Creation
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

    func handleGeocodingError(_ error: Error) -> Error {
        if let error = error as? PirateIslandError {
            return error
        } else if let error = error as? GeocodingError {
            return PirateIslandError.geocodingError
        } else {
            return PirateIslandError.savingError
        }
    }
    
    // MARK: - Validation
    
    public func validateIslandData(_ name: String, _ location: String, _ createdByUserId: String) -> Bool {
        ![name, location, createdByUserId].isEmpty
    }
    
    // MARK: - Geocoding
    

    
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
        
        do {
            let count = try persistenceController.viewContext.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error counting islands: \(error.localizedDescription)")
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
            island.longitude = 0.0 // Default location
        }
    }
    
    func updatePirateIsland(
        island: PirateIsland,
        name: String,
        location: String,
        lastModifiedByUserId: String,
        gymWebsiteURL: URL?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
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
                completion(.failure(PirateIslandError.geocodingError))
            }
        }
    }
    
    func updatePirateIslandLatitudeLongitude(latitude: Double, longitude: Double, island: PirateIsland, completion: @escaping (Result<Void, Error>) -> Void) {
        guard island.managedObjectContext != nil else {
            completion(.failure(PirateIslandError.invalidInput))
            return
        }
        
        island.latitude = latitude
        island.longitude = longitude
        
        Task {
            do {
                try persistenceController.saveContext()
                completion(.success(()))
            } catch {
                completion(.failure(PirateIslandError.savingError))
            }
        }
    }
}

extension PirateIsland {
    var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
