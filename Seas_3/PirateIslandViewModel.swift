import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation


class PirateIslandViewModel: ObservableObject {
    @Published var selectedDestination: IslandDestination?
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    func createPirateIsland(name: String, location: String, createdByUserId: String, gymWebsiteURL: URL?, completion: @escaping (Result<Void, Error>) -> Void) {
        print("Creating gym with name: \(name), location: \(location)")

        // Check if name, location, and createdByUserId are not empty strings
        if name.isEmpty || location.isEmpty || createdByUserId.isEmpty {
            print("Name, location, and createdByUserId cannot be empty.")
            completion(.failure(NSError(domain: "PirateIslandViewModel", code: 101, userInfo: [NSLocalizedDescriptionKey: "Name, location, and createdByUserId cannot be empty."])))
            return
        }

        // Check if an island with the same name already exists
        if pirateIslandExists(name: name) {
            print("Gym with name \(name) already exists. Skipping creation.")
            completion(.failure(NSError(domain: "PirateIslandViewModel", code: 100, userInfo: [NSLocalizedDescriptionKey: "Gym with this name already exists."])))
            return
        }

        // Create a new PirateIsland instance using the PersistenceController's viewContext
        let newIsland = PirateIsland(context: persistenceController.viewContext)
        newIsland.islandName = name
        newIsland.islandLocation = location
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = createdByUserId
        newIsland.lastModifiedByUserId = createdByUserId
        newIsland.lastModifiedTimestamp = Date()

        // Set gymWebsiteURL if it's not nil
        if let gymWebsiteURL = gymWebsiteURL {
            newIsland.gymWebsite = gymWebsiteURL
        }

        // Geocode address using GeocodingUtility
        geocodeAddress(location) { result in
            switch result {
            case .success(let coordinates):
                newIsland.latitude = coordinates.latitude
                newIsland.longitude = coordinates.longitude
                
                // Use the PersistenceController's saveContext method
                do {
                    try self.persistenceController.saveContext()
                    print("Gym geocoded and saved successfully")
                    completion(.success(()))
                } catch {
                    print("Failed to save context: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                print("Geocoding error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    private func pirateIslandExists(name: String) -> Bool {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName == %@", name)

        do {
            let count = try persistenceController.viewContext.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking if gym exists: \(error.localizedDescription)")
            return false
        }
    }

    func validateIsland(name: String, location: String) -> Bool {
        // Check if name and location are not empty
        if name.isEmpty || location.isEmpty {
            return false
        }
        
        // Check if an island with the same name already exists
        if pirateIslandExists(name: name) {
            return false
        }
        
        return true
    }
}
