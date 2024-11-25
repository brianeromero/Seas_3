import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation
import Firebase
import FirebaseFirestore
import os

enum PirateIslandError: Error {
    case invalidInput
    case islandExists
    case geocodingError(String)
    case savingError(String)
    case fieldMissing(String)
    case islandNameMissing
    case streetMissing
    case cityMissing
    case stateMissing
    case zipMissing

    var localizedDescription: String {
        switch self {
        case .invalidInput:
            return "Invalid input"
        case .islandExists:
            return "Island already exists"
        case .geocodingError(let message):
            return "Geocoding error: \(message)"
        case .savingError(let message):
            return "Error saving data: \(message)"
        case .fieldMissing(let field):
            return "\(field) is required"
        case .islandNameMissing:
            return "Island name is missing"
        case .streetMissing:
            return "Street address is missing"
        case .cityMissing:
            return "City is missing"
        case .stateMissing:
            return "State is missing"
        case .zipMissing:
            return "Zip code is missing"
        }
    }
}

public class PirateIslandViewModel: ObservableObject {
    @Published var coordinates: CLLocationCoordinate2D?
    @Published var selectedDestination: IslandDestination?
    let logger = OSLog(subsystem: "Seas3.Subsystem", category: "CoreData")
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    
    
    // MARK: - Geocoding
    public func geocodeAddress(_ address: String) async throws -> (latitude: Double, longitude: Double) {
        try await geocode(address: address, apiKey: GeocodingConfig.apiKey)
    }
    
    // MARK: - Create Pirate Island
    func createPirateIsland(islandDetails: IslandDetails, createdByUserId: String) async throws -> PirateIsland {
        // Log values before validation
        print("Island Name before validation: \(islandDetails.islandName)")
        print("Full Address before validation: \(islandDetails.fullAddress)")
        
        // Step 1: Validate the island details
        guard validateIslandDetails(islandDetails, createdByUserId) else {
            throw PirateIslandError.invalidInput
        }

        os_log("Validation succeeded for Island Name: %@, Full Address: %@", log: logger, islandDetails.islandName, islandDetails.fullAddress)
        
        // Step 2: Check if island already exists
        guard !pirateIslandExists(name: islandDetails.islandName) else {
            throw PirateIslandError.islandExists
        }

        // Step 3: Geocode the address
        os_log("Attempting geocoding for address: %@", log: logger, islandDetails.fullAddress)
        let coordinates: (latitude: Double, longitude: Double)
        
        do {
            coordinates = try await geocodeAddress(islandDetails.fullAddress)
            os_log("Geocoding successful: Lat: %@, Long: %@", log: logger, "\(coordinates.latitude)", "\(coordinates.longitude)")
        } catch {
            os_log("Geocoding failed: %@", log: logger, error.localizedDescription)
            throw PirateIslandError.geocodingError(error.localizedDescription)
        }

        // Step 4: Create the new PirateIsland object
        let newIsland = PirateIsland(context: persistenceController.viewContext)
        newIsland.islandName = islandDetails.islandName
        newIsland.islandLocation = islandDetails.fullAddress
        newIsland.country = islandDetails.country
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = createdByUserId
        newIsland.lastModifiedByUserId = createdByUserId
        newIsland.lastModifiedTimestamp = Date()
        newIsland.gymWebsite = islandDetails.gymWebsiteURL
        newIsland.islandID = UUID()
        newIsland.latitude = coordinates.latitude
        newIsland.longitude = coordinates.longitude
        
        // Step 5: Save the new island object to Core Data
        do {
            // Log before saving
            let islandName = newIsland.islandName ?? "Unknown Island Name" // Default value if nil
            let islandLocation = newIsland.islandLocation ?? "Unknown Location" // Default value if nil

            print("Saving Island: \(islandName), Location: \(islandLocation)")

            try await persistenceController.saveContext()  // Ensure the context is saved
            os_log("Successfully saved PirateIsland: %@", log: logger, islandName)
        } catch {
            os_log("Error saving PirateIsland: %@", log: logger, error.localizedDescription)
            throw PirateIslandError.savingError(error.localizedDescription)  // Handle save error
        }

        return newIsland  // Return the saved island
    }

    
    // MARK: - Validation
    private func validateIslandDetails(_ details: IslandDetails, _ createdByUserId: String) -> Bool {
        let requiredFields = [
            ("Island Name", details.islandName),
            ("Street", details.street),
            ("City", details.city),
            ("State", details.state),
            ("Zip", details.zip),
            ("Created By User ID", createdByUserId)
        ]
        
        for (fieldName, value) in requiredFields {
            // Debug logging for all values
            os_log("Validating %@: %@", log: logger, fieldName, value)
            
            // Check trimmed value
            if value.trimmingCharacters(in: .whitespaces).isEmpty {
                os_log("Validation failed: %@ is missing (%@)", log: logger, fieldName, value)
                return false
            }
        }
        
        return true
    }

    
    // MARK: - Check Existing Islands
    private func pirateIslandExists(name: String) -> Bool {
        let fetchRequest = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName == %@", name)
        
        do {
            let count = try persistenceController.viewContext.count(for: fetchRequest)
            return count > 0
        } catch {
            os_log("Error checking existing islands: %@", log: logger, error.localizedDescription)
            return false
        }
    }
    
    func updatePirateIsland(island: PirateIsland, islandDetails: IslandDetails, lastModifiedByUserId: String) async throws {
        island.islandName = islandDetails.islandName
        island.islandLocation = islandDetails.fullAddress
        island.country = islandDetails.country
        island.lastModifiedByUserId = lastModifiedByUserId
        island.lastModifiedTimestamp = Date()
        island.gymWebsite = islandDetails.gymWebsiteURL
        
        try await persistenceController.saveContext()
    }
    
}
