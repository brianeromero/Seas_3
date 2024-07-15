import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation

class PirateIslandViewModel: ObservableObject {
    @Published var selectedDestination: IslandDestination?
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func createPirateIsland(name: String, location: String, createdByUserId: String, gymWebsiteURL: URL?, completion: @escaping (Result<Void, Error>) -> Void) {
        print("Creating pirate island with name: \(name), location: \(location)")

        // Check if an island with the same name already exists
        if pirateIslandExists(name: name) {
            print("Pirate island with name \(name) already exists. Skipping creation.")
            completion(.failure(NSError(domain: "PirateIslandViewModel", code: 100, userInfo: [NSLocalizedDescriptionKey: "Island with this name already exists."])))
            return
        }

        let newIsland = PirateIsland(context: context)
        newIsland.islandName = name
        newIsland.islandLocation = location
        newIsland.createdTimestamp = Date()
        newIsland.createdByUserId = createdByUserId
        newIsland.lastModifiedByUserId = createdByUserId
        newIsland.lastModifiedTimestamp = Date()
        newIsland.gymWebsite = gymWebsiteURL

        // Geocode address using GeocodingUtility
        geocodeAddress(location) { result in
            switch result {
            case .success(let coordinates):
                newIsland.latitude = coordinates.latitude
                newIsland.longitude = coordinates.longitude
                self.saveContext()
                print("Island geocoded successfully")
                completion(.success(()))
            case .failure(let error):
                print("Geocoding error: \(error.localizedDescription)")
                completion(.failure(error))
                // Handle geocoding failure appropriately, e.g., show an error message
            }
        }
    }

    private func pirateIslandExists(name: String) -> Bool {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandName == %@", name)

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Failed to fetch data: \(error)")
            return false
        }
    }

    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("Context saved successfully.")
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
}
