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

@MainActor
public class PirateIslandViewModel: ObservableObject {
    @Published var coordinates: CLLocationCoordinate2D?
    @Published var selectedDestination: IslandDestination?
    let logger = OSLog(subsystem: "Mat_Finder.Subsystem", category: "CoreData")
    
    private let persistenceController: PersistenceController

    // NO default argument here
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }


    // MARK: - Create Pirate Island
    @MainActor
    func createPirateIsland(
        islandDetails: IslandDetails,
        createdByUserId: String,
        gymWebsite: String?,
        country: String,
        selectedCountry: Country,
        createdByUser: User
    ) async throws -> PirateIsland {

        os_log(
            "createPirateIsland called with Island Name: %@, Location: %@",
            log: self.logger,
            type: .info,
            islandDetails.islandName,
            islandDetails.fullAddress
        )

        // Step 1: Validate
        let isValid = try validateIslandDetails(islandDetails, createdByUserId, country, selectedCountry)
        guard isValid else { throw PirateIslandError.invalidInput }

        // Step 2: Update country
        islandDetails.country = country

        // Step 3: Check for duplicates
        guard await !pirateIslandExists(name: islandDetails.islandName) else {
            os_log("Island already exists: %@", log: self.logger, type: .error, islandDetails.islandName)
            throw PirateIslandError.islandExists
        }

        // Step 4: Geocode
        let coordinates = try await geocodeAddress(islandDetails.fullAddress.cleanedForGeocoding)

        // Step 5: Create NSManagedObject in a background context
        let backgroundContext = persistenceController.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // ✅ Thread-safe copies
        let islandName = islandDetails.islandName
        let fullAddress = islandDetails.fullAddress
        let countryName = selectedCountry.name.common
        let latitude = coordinates.latitude
        let longitude = coordinates.longitude
        let websiteURL = islandDetails.gymWebsiteURL
        let createdBy = createdByUserId

        var newIslandObjectID: NSManagedObjectID!

        try await backgroundContext.perform {
            let newIsland = PirateIsland(context: backgroundContext)
            newIsland.islandID = UUID()
            newIsland.islandName = islandName
            newIsland.islandLocation = fullAddress
            newIsland.country = countryName
            newIsland.latitude = latitude
            newIsland.longitude = longitude
            newIsland.createdTimestamp = Date()
            newIsland.createdByUserId = createdBy
            newIsland.lastModifiedByUserId = createdBy
            newIsland.lastModifiedTimestamp = Date()

            // Gym website
            if let websiteURL = websiteURL, !websiteURL.absoluteString.isEmpty {
                guard websiteURL.absoluteString.isValidURL() else {
                    os_log("Invalid gym website URL: %@", log: self.logger, type: .error, websiteURL.absoluteString)
                    throw PirateIslandError.invalidGymWebsite
                }
                newIsland.gymWebsite = websiteURL
            }

            try backgroundContext.save()
            newIslandObjectID = newIsland.objectID
        }

        // Step 6: Fetch on main context and upload to Firestore
        let mainContextIsland = try persistenceController.container.viewContext.existingObject(with: newIslandObjectID) as! PirateIsland
        let islandData = FirestoreIslandData(from: mainContextIsland)
        try await FirestoreManager.shared.saveIslandToFirestore(
            islandData: islandData,
            selectedCountry: selectedCountry,
            createdByUser: createdByUser  // <-- Pass User, not String
            
        )

        return mainContextIsland
    }


    // MARK: - Save to Firestore
    @MainActor
    func savePirateIslandToFirestore(
        island: PirateIsland,
        selectedCountry: Country,
        createdByUser: User
    ) async throws {
        // Capture a safe snapshot of the Core Data object on the Main Actor
        let islandData = FirestoreIslandData(from: island)

        // Log the data being uploaded
        os_log(
            "Saving island to Firestore: %@ (id: %@) — lat: %f, long: %f",
            log: logger,
            type: .info,
            islandData.name,
            islandData.id,
            islandData.latitude,
            islandData.longitude
        )

        // Call Firestore manager (this is an async network call).
        // Running the network call while on MainActor is acceptable here because:
        //  - we've already created a value-type snapshot (islandData),
        //  - FirestoreManager methods are async and will suspend, allowing the main actor to yield.
        try await FirestoreManager.shared.saveIslandToFirestore(
            islandData: islandData,
            selectedCountry: selectedCountry,
            createdByUser: createdByUser
        )

        os_log("Finished saving island to Firestore: %@", log: logger, type: .info, islandData.name)
    }



    // MARK: - Validation
    func validateIslandDetails(
        _ details: IslandDetails,
        _ createdByUserId: String?,
        _ countryCode: String,
        _ selectedCountry: Country?
    ) throws -> Bool {
        do {
            let requiredFields = try getAddressFields(for: selectedCountry?.cca2.uppercased() ?? "")

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

            for (fieldName, value) in fieldValues {
                os_log("Validating %@: %@", log: logger, fieldName, value ?? "nil")
                let camelCaseFieldName = fieldName.capitalizingFirstLetter()
                
                if let field = AddressField(rawValue: camelCaseFieldName),
                   let fieldType = AddressFieldType(rawValue: field.rawValue),
                   requiredFields.contains(fieldType) {
                    
                    if value?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                        os_log("Validation failed: %@ is missing (%@)", log: logger, fieldName, value ?? "nil")
                        throw PirateIslandError.fieldMissing(fieldName)
                    }
                }
            }

            return true
        } catch {
            os_log(
                "Error getting address fields for country code %@: %@",
                log: logger,
                countryCode,
                "\(error)"
            )
            throw error
        }
    }

    // MARK: - Check Existing Islands
    func pirateIslandExists(name: String) async -> Bool {
        let context = persistenceController.viewContext
        let logger = self.logger

        return await context.perform {
            let fetchRequest = PirateIsland.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "islandName ==[c] %@", name)
            fetchRequest.fetchLimit = 1

            do {
                let count = try context.count(for: fetchRequest)
                return count > 0
            } catch {
                os_log("Error checking existing islands: %@", log: logger, error.localizedDescription)
                return false
            }
        }
    }

    // MARK: - Update Pirate Island
    func updatePirateIsland(id: String, data: [String: Any]) async throws {
        if FirestoreManager.shared.disabled { return }
        print("Updating pirate island with id: \(id)")
        try await FirestoreManager.shared.updateDocument(in: .pirateIslands, id: id, data: data)
        print("Pirate island updated successfully")
    }

    // MARK: - Delete Pirate Island
    @MainActor
    func deletePirateIsland(_ island: PirateIsland) async throws {
        let context = PersistenceController.shared.viewContext

        guard let islandID = island.islandID?.uuidString else {
            throw NSError(
                domain: "PirateIslandViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "PirateIsland has no ID"]
            )
        }

        // 1️⃣ Delete from Firestore
        do {
            try await Firestore.firestore()
                .collection("pirateIslands")
                .document(islandID)
                .delete()
            print("✅ Deleted PirateIsland \(island.islandName ?? "") from Firestore.")
        } catch {
            print("❌ Failed to delete PirateIsland from Firestore: \(error.localizedDescription)")
            throw error
        }

        // 2️⃣ Delete from Core Data
        context.delete(island)
        do {
            try context.save()
            print("✅ Deleted PirateIsland \(island.islandName ?? "") from Core Data.")
        } catch {
            print("❌ Failed to delete PirateIsland from Core Data: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - String Helpers
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
