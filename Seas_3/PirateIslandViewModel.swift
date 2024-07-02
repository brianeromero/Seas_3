import SwiftUI
import Foundation
import CoreData


class PirateIslandViewModel: ObservableObject {
    @Published var selectedDestination: IslandDestination?
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func createPirateIsland(name: String, location: String, createdByUserId: String, gymWebsiteURL: URL?) {
        print("Creating pirate island with name: \(name), location: \(location)")

        // Check if an island with the same name already exists
        if pirateIslandExists(name: name) {
            print("Pirate island with name \(name) already exists. Skipping creation.")
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

        logIslandUpdate(island: newIsland) // Logging the update here

        saveContext()
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

    private func logIslandUpdate(island: PirateIsland) {
        // Only log significant changes or batched updates
        let logString = """
            Updated Island:
            islandName: \(island.islandName)
            islandLocation: \(island.islandLocation)
            createdByUserId: \(island.createdByUserId ?? "")
            gymWebsite: \(island.gymWebsite?.absoluteString ?? "")
            """

        print(logString)
    }
}
