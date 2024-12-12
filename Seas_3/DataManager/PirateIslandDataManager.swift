//
//  PirateIslandDataManager.swift
//  Seas_3
//
//  Created by Brian Romero on 8/5/24.
//

import Foundation
import CoreData

class PirateIslandDataManager {
    private var viewContext: NSManagedObjectContext

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    enum FetchError: Error {
        case failedFetchingIslands(Error)
    }

    enum PersistenceError: Error {
        case invalidRecordId(String)
        case recordNotFound(String)
    }

    func fetchPirateIslands(sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil, fetchLimit: Int? = nil) -> Result<[PirateIsland], FetchError> {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        if let fetchLimit = fetchLimit {
            fetchRequest.fetchLimit = fetchLimit
        }
        do {
            let pirateIslands = try viewContext.fetch(fetchRequest)
            return .success(pirateIslands)
        } catch let error {
            return .failure(.failedFetchingIslands(error))
        }
    }
    
    
    func fetchLocalPirateIsland(withId id: String) async throws -> PirateIsland? {
        print("Fetching local pirate island with id: \(id)")
        
        guard let uuid = UUID(uuidString: id) else {
            print("Failed to convert id to UUID")
            throw PersistenceError.invalidRecordId(id)
        }
        
        print("Successfully converted id to UUID: \(uuid.uuidString)")
        
        let result = try await fetchPirateIsland(uuid: uuid)
        
        print("Attempting to fetch pirate island with UUID...")
        
        return result
    }

    private func fetchPirateIsland(uuid: UUID) async throws -> PirateIsland? {
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
            throw error
        }
    }
}
