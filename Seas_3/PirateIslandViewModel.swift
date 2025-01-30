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
    case postalCodeMissing
    case invalidGymWebsite

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
        case .postalCodeMissing:
            return "Postal code is missing"
        case .invalidGymWebsite:
            return "Confirm website validity"
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
    func createPirateIsland(islandDetails: IslandDetails, createdByUserId: String, gymWebsite: String?, country: String) async throws -> PirateIsland {
        os_log("createPirateIsland called with Island Name: %@, Location: %@", log: logger, type: .info, islandDetails.islandName, islandDetails.fullAddress)

        // Generate a new UUID
        let newIslandID = UUID()

        // Step 1: Validate the island details
        guard validateIslandDetails(islandDetails, createdByUserId, country) else {
            throw PirateIslandError.invalidInput
        }

        os_log("Validation succeeded for Island Name: %@, Full Address999: %@", log: logger, type: .info, islandDetails.islandName, islandDetails.fullAddress)

        // Step 2: Check if the island already exists
        guard !pirateIslandExists(name: islandDetails.islandName) else {
            os_log("Island already exists: %@", log: logger, type: .error, islandDetails.islandName)
            throw PirateIslandError.islandExists
        }

        // Step 3: Geocode the address to get coordinates
        os_log("Attempting geocoding for address: %@", log: logger, type: .info, islandDetails.fullAddress)
        let coordinates: (latitude: Double, longitude: Double)

        do {
            coordinates = try await geocodeAddress(islandDetails.fullAddress)
            os_log("Geocoding successful: Lat: %@, Long: %@", log: logger, "\(coordinates.latitude)", "\(coordinates.longitude)")
        } catch {
            os_log("Geocoding failed: %@", log: logger, type: .error, error.localizedDescription)
            throw PirateIslandError.geocodingError(error.localizedDescription)
        }

        // Step 4: Create the new PirateIsland object
        let newIsland = PirateIsland(context: persistenceController.viewContext)
        newIsland.islandID = newIslandID  // Assign new UUID
        newIsland.islandName = islandDetails.islandName
        newIsland.islandLocation = islandDetails.fullAddress
        newIsland.country = country
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = createdByUserId
        newIsland.lastModifiedByUserId = createdByUserId
        newIsland.lastModifiedTimestamp = Date()

        // Step 5: Convert the gymWebsite string to a URL
        if let website = gymWebsite, !website.isEmpty {
            if let url = URL(string: website) {
                newIsland.gymWebsite = url
            } else {
                os_log("Invalid Gym Website URL: %@", log: logger, type: .error, website)
                throw PirateIslandError.invalidGymWebsite
            }
        }

        newIsland.latitude = coordinates.latitude
        newIsland.longitude = coordinates.longitude

        os_log("Prepared new PirateIsland for saving: %@, %@, Lat: %@, Long: %@", log: logger, newIsland.islandName ?? "Unknown", newIsland.islandLocation ?? "Unknown", "\(newIsland.latitude)", "\(newIsland.longitude)")

        // Step 6:  Save to Core Data first
        do {
            try await persistenceController.saveContext()
            os_log("Successfully saved PirateIsland: %@", log: logger, type: .info, newIsland.islandName ?? "Unknown Island Name")
        } catch {
            os_log("Error saving PirateIsland: %@", log: logger, type: .error, error.localizedDescription)
            throw error
        }

        // Step 7:  Then save to Firestore
        try await savePirateIslandToFirestore(island: newIsland)

        os_log("Successfully created PirateIsland with name: %@", log: logger, newIsland.islandName ?? "Unknown Island Name")
        return newIsland
    }

    // Add this code below the createPirateIsland function
    func savePirateIslandToFirestore(island: PirateIsland) async throws {
        print("Saving island to Firestore: \(island.safeIslandName)")
        
        // Add some debug prints here
        print("Island name: \(island.islandName ?? "")")
        print("Island location: \(island.islandLocation ?? "")")
        print("Gym website URL: \(island.gymWebsite?.absoluteString ?? "")")
        print("Latitude: \(island.latitude)")
        print("Longitude: \(island.longitude)")
        

        do {
            try await FirestoreManager.shared.saveIslandToFirestore(island: island)
        } catch {
            os_log("Error saving island to Firestore: %@", log: logger, error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Validation
    func validateIslandDetails(_ details: IslandDetails, _ createdByUserId: String?, _ countryCode: String) -> Bool {
        do {
            let requiredFields = try getAddressFields(for: countryCode.uppercased())
            var isValid = true

            // Prepare field values for logging and validation
            let fieldValues: [String: String?] = [
                "street": requiredFields.contains(.street) ? details.street : nil,
                "city": requiredFields.contains(.city) ? details.city : nil,
                "state": requiredFields.contains(.state) ? details.state : nil,
                "province": requiredFields.contains(.province) ? details.province : nil,
                "postalCode": requiredFields.contains(.postalCode) ? details.postalCode : nil,
                "department": requiredFields.contains(.department) ? details.department : nil,
                "county": requiredFields.contains(.county) ? details.county : nil,
                "neighborhood": requiredFields.contains(.neighborhood) ? details.neighborhood : nil,
                "complement": requiredFields.contains(.complement) ? details.complement : nil,
                "block": requiredFields.contains(.block) ? details.block : nil,
                "apartment": requiredFields.contains(.apartment) ? details.apartment : nil,
                "region": requiredFields.contains(.region) ? details.region : nil,
                "district": requiredFields.contains(.district) ? details.district : nil,
                "governorate": requiredFields.contains(.governorate) ? details.governorate : nil,
                "emirate": requiredFields.contains(.emirate) ? details.emirate : nil,
                "island": requiredFields.contains(.island) ? details.island : nil,
                "division": requiredFields.contains(.division) ? details.division : nil,
                "zone": requiredFields.contains(.zone) ? details.zone : nil
            ]

            // Validate each field and log the process
            for (fieldName, value) in fieldValues {
                os_log("Validating %@: %@", log: logger, fieldName, value ?? "nil")
                let camelCaseFieldName = fieldName.capitalizingFirstLetter()
                if let field = AddressField(rawValue: camelCaseFieldName), requiredFields.contains(AddressFieldType(rawValue: field.rawValue)!) {
                    if let value = value, value.trimmingCharacters(in: .whitespaces).isEmpty {
                        os_log("Validation failed: %@ is missing (%@)", log: logger, fieldName, value)
                        isValid = false
                    }
                }
            }

            return isValid
        } catch {
            os_log("Error getting address fields for country code %@: %@", log: logger, countryCode, error.localizedDescription)
            return false
        }
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

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }
}
