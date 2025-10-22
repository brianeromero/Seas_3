//
//  PirateIslandDataManager.swift
//  Mat_Finder
//
//  Created by Brian Romero on 8/5/24.
//

import Foundation
import CoreData

public class PirateIslandDataManager: ObservableObject { // Assuming you've made it ObservableObject as discussed
    internal var viewContext: NSManagedObjectContext // Or 'public' if needed outside the module

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    enum FetchError: Error {
        case failedFetchingIslands(Error)
        // ADD THESE TWO CASES:
        case unknownError(Error) // Add this line
        case coreDataError(Error) // Add this line
    }

    enum PersistenceError: Error {
        case invalidRecordId(String)
        case recordNotFound(String)
        case mockError(String) // You might want a specific mock error too for completeness, or just use `unknownError`

    }

    func fetchPirateIslands(sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil, fetchLimit: Int? = nil) -> Result<[PirateIsland], FetchError> {
        // Crucial: Ensure Core Data operations happen on the correct thread/queue
        var result: Result<[PirateIsland], FetchError>! // Declare as implicitly unwrapped optional
        
        // Use performAndWait to ensure the block completes before returning
        viewContext.performAndWait {
            let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
            fetchRequest.sortDescriptors = sortDescriptors
            fetchRequest.predicate = predicate
            if let fetchLimit = fetchLimit {
                fetchRequest.fetchLimit = fetchLimit
            }
            do {
                print("Performing fetch inside viewContext.performAndWait on thread: \(Thread.current)") // Check thread again
                let pirateIslands = try self.viewContext.fetch(fetchRequest) // Use self.viewContext inside the block
                result = .success(pirateIslands)
            } catch let error {
                print("Error fetching pirate islands inside performAndWait: \(error.localizedDescription)")
                result = .failure(.failedFetchingIslands(error))
            }
        }
        return result // Now 'result' will have been set
    }
    
    func fetchLocalPirateIsland(withId id: String) async throws -> PirateIsland? {
        print("Fetching local pirate island with id: \(id)")
            
        guard let uuid = UUID(uuidString: id) else {
            print("Failed to convert id to UUID")
            throw PersistenceError.invalidRecordId(id)
        }
            
        print("Successfully converted id to UUID: \(uuid.uuidString)")
            
        // The call to fetchPirateIsland (which calls fetchPirateIslands) will now be safely dispatched
        // by the performAndWait within fetchPirateIslands.
        let result = try await fetchPirateIsland(uuid: uuid)
            
        print("Attempting to fetch pirate island with UUID...")
            
        return result
    }
    
    private func fetchPirateIsland(uuid: UUID) async throws -> PirateIsland? {
        // This is an async function, but it calls the synchronous fetchPirateIslands,
        // which now correctly uses performAndWait to handle threading.
        let predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
        let result = fetchPirateIslands(predicate: predicate, fetchLimit: 1)
            
        switch result {
        case .success(let pirateIslands):
            if !pirateIslands.isEmpty {
                print("Successfully fetched pirate island with UUID")
                return pirateIslands.first
            } else {
                print("No pirate island found with UUID")
                throw PersistenceError.recordNotFound(uuid.uuidString)
            }
        case .failure(let error):
            print("Error fetching local pirate island with UUID: \(error.localizedDescription)")
            throw error // Re-throw the original error
        }
    }
}
