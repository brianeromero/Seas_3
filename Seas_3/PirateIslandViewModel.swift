import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation
import FirebaseFirestore
import os

enum PirateIslandError: Error {
    case invalidInput
    case islandExists
    case islandNameMissing
    case geocodingError(String)
    case savingError
    
    var localizedDescription: String {
        switch self {
        case .invalidInput:
            return "Invalid input"
        case .islandExists:
            return "Island already exists"
        case .islandNameMissing:
            return "Island name is missing"
        case .geocodingError(let message):
            return "Geocoding error: \(message)"
        case .savingError:
            return "Saving error"
        }
    }
}

public class PirateIslandViewModel: ObservableObject {
    @Published var pirateIsland: PirateIsland?
    @Published var firestoreDocumentID: String? // Add this property to store the document ID
    @Published var selectedDestination: IslandDestination?
    @Published var coordinates: CLLocationCoordinate2D?

    var firestore = Firestore.firestore()
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
        
        do {
            let coordinates = try await geocodeAddress(location)
            self.coordinates = CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
            
            // Save to Firestore
            let firestoreDocument = firestore.collection("pirateIslands").document()
            try await firestoreDocument.setData([
                "name": name,
                "location": location,
                "createdByUserId": createdByUserId,
                "gymWebsiteURL": gymWebsiteURL?.absoluteString as Any,
                "latitude": coordinates.latitude,
                "longitude": coordinates.longitude,
            ])
            
            // Cache in Core Data
            let newIsland = PirateIsland(context: persistenceController.viewContext)
            newIsland.islandName = name
            newIsland.islandLocation = location
            newIsland.createdTimestamp = Date()
            newIsland.createdByUserId = createdByUserId
            newIsland.lastModifiedByUserId = createdByUserId
            newIsland.lastModifiedTimestamp = Date()
            newIsland.gymWebsite = gymWebsiteURL
            newIsland.islandID = UUID()
            newIsland.latitude = coordinates.latitude
            newIsland.longitude = coordinates.longitude
            
            try await persistenceController.saveContext()
            completion(.success(newIsland))
        } catch {
            completion(.failure(PirateIslandError.savingError))
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
        
        guard validateIslandData(name, location, createdByUserId) else {
            return .failure(PirateIslandError.invalidInput)
        }
        
        guard !pirateIslandExists(name: name) else {
            return .failure(PirateIslandError.islandExists)
        }
        
        do {
            let coordinates = try await geocodeAddress(location)
            self.coordinates = CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
            
            // Save to Firestore
            let firestoreDocument = firestore.collection("pirateIslands").document()
            try await firestoreDocument.setData([
                "name": islandDetails.islandName,
                "location": location,
                "createdByUserId": createdByUserId,
                "gymWebsiteURL": gymWebsiteURL?.absoluteString as Any,
                "latitude": coordinates.latitude,
                "longitude": coordinates.longitude,
            ])
            
            // Cache in Core Data
            let newIsland = PirateIsland(context: persistenceController.viewContext)
            newIsland.islandName = islandDetails.islandName
            newIsland.islandLocation = location
            newIsland.createdTimestamp = Date()
            newIsland.createdByUserId = createdByUserId
            newIsland.lastModifiedByUserId = createdByUserId
            newIsland.lastModifiedTimestamp = Date()
            newIsland.gymWebsite = gymWebsiteURL
            newIsland.islandID = UUID()
            newIsland.latitude = coordinates.latitude
            newIsland.longitude = coordinates.longitude
            
            try await persistenceController.saveContext()
            return .success(newIsland)
        } catch {
            return .failure(PirateIslandError.savingError)
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
    func saveIslandData(
        _ islandName: String,
        _ street: String,
        _ city: String,
        _ state: String,
        _ zip: String,
        _ province: String,
        _ postalCode: String,
        _ neighborhood: String,
        _ complement: String,
        _ apartment: String,
        _ region: String,
        _ county: String,
        _ governorate: String,
        _ additionalInfo: String,
        _ country: String,
        createdByUserId: String,
        website: URL?
    ) async throws {
        guard validateIslandData(islandName, street, city) else {
            throw PirateIslandError.invalidInput
        }
        
        let fetchRequest = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName == %@", islandName)
        let existingIsland = (try? persistenceController.viewContext.fetch(fetchRequest).first) ?? nil
        var newIsland: PirateIsland? = existingIsland
        
        let coordinates = try await geocodeAddress("\(street), \(city), \(state) \(zip)")
        self.coordinates = CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
        
        // Save to Firestore
        let firestoreDocument = firestore.collection("pirateIslands").document(islandName)
        try await firestoreDocument.setData([
            "name": islandName,
            "location": "\(street), \(city), \(state) \(zip)",
            "gymWebsiteURL": website?.absoluteString as Any,
            "latitude": coordinates.latitude,
            "longitude": coordinates.longitude,
        ])
        
        // Cache in Core Data
        if let existingIsland = existingIsland {
            existingIsland.islandLocation = "\(street), \(city), \(state) \(zip)"
            existingIsland.gymWebsite = website
        } else {
            newIsland = PirateIsland(context: persistenceController.viewContext)
            newIsland?.islandName = islandName
            newIsland?.islandLocation = "\(street), \(city), \(state) \(zip)"
            newIsland?.gymWebsite = website
            newIsland?.islandID = UUID()
            newIsland?.latitude = coordinates.latitude
            newIsland?.longitude = coordinates.longitude
        }
        
        try await persistenceController.saveContext()
    }
    // MARK: - Helpers
    private func pirateIslandExists(name: String) -> Bool {
        let fetchRequest = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName ==[c] %@", name.trimmingCharacters(in: .whitespacesAndNewlines))

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
        
        do {
            let coordinates = try await geocodeAddress(location)
            self.coordinates = CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
            
            // Save to Firestore
            let firestoreDocument = firestore.collection("pirateIslands").document(island.islandName ?? "")
            try await firestoreDocument.updateData([
                "name": name,
                "location": location,
                "lastModifiedByUserId": lastModifiedByUserId,
                "gymWebsiteURL": gymWebsiteURL?.absoluteString as Any,
                "latitude": coordinates.latitude,
                "longitude": coordinates.longitude,
            ])
            
            // Cache in Core Data
            island.islandName = name
            island.islandLocation = location
            island.lastModifiedByUserId = lastModifiedByUserId
            island.gymWebsite = gymWebsiteURL
            island.latitude = coordinates.latitude
            island.longitude = coordinates.longitude
            
            try await persistenceController.saveContext()
            completion(.success(()))
        } catch {
            completion(.failure(PirateIslandError.savingError))
        }
    }
    
    // Make sure this method is async and properly handles the result
    func updatePirateIslandLatitudeLongitude(
        latitude: Double,
        longitude: Double,
        island: PirateIsland
    ) async throws {
        guard let islandName = island.islandName else {
            throw PirateIslandError.islandNameMissing
        }
        
        // Save to Firestore
        let firestoreDocument = firestore.collection("pirateIslands").document(islandName)
        try await firestoreDocument.updateData([
            "latitude": latitude,
            "longitude": longitude,
        ])
        
        // Cache in Core Data
        island.latitude = latitude
        island.longitude = longitude
        
        try await persistenceController.saveContext()
    }
}

extension PirateIsland {
    var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
