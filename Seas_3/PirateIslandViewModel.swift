import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import os

public enum PirateIslandError: Error {
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
    

    // MARK: - Create Pirate Island
    func createPirateIsland(
        islandDetails: IslandDetails,
        createdByUserId: String,
        gymWebsite: String?,
        country: String,
        selectedCountry: Country,
        createdByUser: User
    ) async throws -> PirateIsland {

        os_log("createPirateIsland called with Island Name: %@, Location: %@", log: logger, type: .info, islandDetails.islandName, islandDetails.fullAddress)

        // Log the address being passed for geocoding
        os_log("Geocoding address: %@", log: logger, type: .info, islandDetails.fullAddress)

        // Step 1: Validate the island details
        do {
            let isValid = try validateIslandDetails(islandDetails, createdByUserId, country, selectedCountry)
            if !isValid {
                // Handle invalid state if necessary
                throw PirateIslandError.invalidInput
            }
        } catch {
            // Handle validation errors
            os_log("Validation error: %@", log: logger, error.localizedDescription)
            throw error
        }

        // Update islandDetails.country with the selected country on the main thread
        await MainActor.run {
            islandDetails.country = country
        }

        // Step 3: Check if the island already exists
        guard !pirateIslandExists(name: islandDetails.islandName) else {
            os_log("Island already exists: %@", log: logger, type: .error, islandDetails.islandName)
            throw PirateIslandError.islandExists
        }

        // Step 4: Geocode the address to get coordinates
        os_log("Attempting geocoding for address: %@", log: logger, type: .info, islandDetails.fullAddress)

        let coordinates: (latitude: Double, longitude: Double)

        do {
            // You can still print the raw address if needed
            print("Full Address: \(islandDetails.fullAddress)")
            
            coordinates = try await geocodeAddress(islandDetails.fullAddress.cleanedForGeocoding)
            
            os_log("Geocoding successful: Lat: %@, Long: %@", log: logger, "\(coordinates.latitude)", "\(coordinates.longitude)")
            print("Geocoding response coordinates: \(coordinates)")
            print("Geocoding response full address: \(islandDetails.fullAddress)")
        } catch {
            os_log("Geocoding failed: %@", log: logger, type: .error, error.localizedDescription)
            print("Geocoding error: \(error)")
            throw PirateIslandError.geocodingError(error.localizedDescription)
        }


        // Step 5: Create the new PirateIsland object
        let newIsland = PirateIsland(context: persistenceController.viewContext)
        newIsland.islandID = UUID()  // Assign new UUID
        newIsland.islandName = islandDetails.islandName
        newIsland.islandLocation = islandDetails.fullAddress
        newIsland.country = selectedCountry.name.common
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = createdByUserId
        newIsland.lastModifiedByUserId = createdByUserId
        newIsland.lastModifiedTimestamp = Date()

        // Step 6: Set the gym website URL
        if let websiteURL = islandDetails.gymWebsiteURL {
            let websiteString = websiteURL.absoluteString
            if !websiteString.isEmpty {
                if websiteString.isValidURL() {
                    newIsland.gymWebsite = websiteURL
                } else {
                    os_log("Invalid gym website URL: %@", log: logger, type: .error, websiteString)
                    throw PirateIslandError.invalidGymWebsite
                }
            }
        }



        newIsland.latitude = coordinates.latitude
        newIsland.longitude = coordinates.longitude

        os_log("Prepared new PirateIsland for saving: %@, %@, Lat: %@, Long: %@", log: logger, newIsland.islandName ?? "Unknown", newIsland.islandLocation ?? "Unknown", "\(newIsland.latitude)", "\(newIsland.longitude)")

        // Step 7:  Save to Core Data first
        do {
            try await persistenceController.saveContext()
            os_log("Successfully saved PirateIsland: %@", log: logger, type: .info, newIsland.islandName ?? "Unknown Island Name")
        } catch {
            os_log("Error saving PirateIsland: %@", log: logger, type: .error, error.localizedDescription)
            throw error
        }

        // Step 8:  Then save to Firestore
        try await savePirateIslandToFirestore(island: newIsland, selectedCountry: selectedCountry, createdByUser: createdByUser)

        os_log("Successfully created PirateIsland with name: %@", log: logger, newIsland.islandName ?? "Unknown Island Name")
        return newIsland
    }



    // Add this code below the createPirateIsland function
    func savePirateIslandToFirestore(
        island: PirateIsland,
        selectedCountry: Country,
        createdByUser: User // <-- new parameter
    ) async throws {

        print("Saving island to Firestore: \(island.safeIslandName)")
        
        // Add some debug prints here
        print("Island name: \(island.islandName ?? "")")
        print("Island location: \(island.islandLocation ?? "")")
        print("Gym website URL: \(island.gymWebsite?.absoluteString ?? "")")
        print("Latitude: \(island.latitude)")
        print("Longitude: \(island.longitude)")
        

        do {
            try await FirestoreManager.shared.saveIslandToFirestore(
                island: island,
                selectedCountry: selectedCountry,
                createdByUser: createdByUser
            )

        } catch {
            os_log("Error saving island to Firestore: %@", log: logger, error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Validation
    func validateIslandDetails(_ details: IslandDetails, _ createdByUserId: String?, _ countryCode: String, _ selectedCountry: Country?) throws -> Bool {
        do {
            let requiredFields = try getAddressFields(for: selectedCountry?.cca2.uppercased() ?? "")
            
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
                
                // Validate fields that are required
                if let field = AddressField(rawValue: camelCaseFieldName),
                   let fieldType = AddressFieldType(rawValue: field.rawValue),
                   requiredFields.contains(fieldType) {
                    
                    // If value is missing or empty, throw the corresponding error
                    if value?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                        os_log("Validation failed: %@ is missing (%@)", log: logger, fieldName, value ?? "nil")
                        throw PirateIslandError.fieldMissing(fieldName)
                    }
                }
            }

            return true // All fields are valid
        } catch {
            os_log("Error getting address fields for country code %@: %@", log: logger, countryCode, "\(error)")
            throw error // Rethrow the caught error
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
    
    // THIS IS THE ONLY updatePirateIsland FUNCTION THAT SHOULD BE IN THIS CLASS
    // It calls the FirestoreManager to update Firestore.
    func updatePirateIsland(id: String, data: [String: Any]) async throws {
        if FirestoreManager.shared.disabled { return } // Use FirestoreManager's disabled flag
        print("Updating pirate island with id: \(id)")
        try await FirestoreManager.shared.updateDocument(in: .pirateIslands, id: id, data: data)
        print("Pirate island updated successfully")
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        prefix(1).uppercased() + dropFirst()
    }

    var cleanedForGeocoding: String {
        replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isValidURL() -> Bool {
        guard let url = URL(string: self), UIApplication.shared.canOpenURL(url) else {
            return false
        }
        return true
    }

}
