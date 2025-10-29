//
//  PirateIslandDataManager.swift
//  Mat_Finder
//
//  Created by Brian Romero on 8/5/24.
//

import Foundation
import CoreData

public class PirateIslandDataManager: ObservableObject {
    internal var viewContext: NSManagedObjectContext

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    enum FetchError: Error {
        case failedFetchingIslands(Error)
        case unknownError(Error)
        case coreDataError(Error)
    }

    enum PersistenceError: Error {
        case invalidRecordId(String)
        case recordNotFound(String)
        case mockError(String)
    }

    func fetchPirateIslands(sortDescriptors: [NSSortDescriptor]? = nil,
                             predicate: NSPredicate? = nil,
                             fetchLimit: Int? = nil) -> Result<[PirateIsland], FetchError> {
        var result: Result<[PirateIsland], FetchError>!
        
        viewContext.performAndWait {
            let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
            fetchRequest.sortDescriptors = sortDescriptors
            fetchRequest.predicate = predicate
            if let fetchLimit = fetchLimit {
                fetchRequest.fetchLimit = fetchLimit
            }
            do {
                let pirateIslands = try self.viewContext.fetch(fetchRequest)
                result = .success(pirateIslands)
            } catch let error {
                result = .failure(.failedFetchingIslands(error))
            }
        }
        return result
    }

    func fetchLocalPirateIsland(withId id: String) async throws -> PirateIsland? {
        guard let uuid = UUID(uuidString: id) else {
            throw PersistenceError.invalidRecordId(id)
        }
        return try await fetchPirateIsland(uuid: uuid)
    }

    private func fetchPirateIsland(uuid: UUID) async throws -> PirateIsland? {
        let predicate = NSPredicate(format: "islandID == %@", uuid as CVarArg)
        let result = fetchPirateIslands(predicate: predicate, fetchLimit: 1)
        switch result {
        case .success(let pirateIslands):
            if !pirateIslands.isEmpty { return pirateIslands.first }
            else { throw PersistenceError.recordNotFound(uuid.uuidString) }
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Async wrapper extension
extension PirateIslandDataManager {
    /// Async wrapper around the existing synchronous fetchPirateIslands
    func fetchPirateIslandsAsync(sortDescriptors: [NSSortDescriptor]? = nil,
                                 predicate: NSPredicate? = nil,
                                 fetchLimit: Int? = nil) async throws -> [PirateIsland] {
        try await withCheckedThrowingContinuation { continuation in
            let result = self.fetchPirateIslands(sortDescriptors: sortDescriptors,
                                                 predicate: predicate,
                                                 fetchLimit: fetchLimit)
            switch result {
            case .success(let islands):
                continuation.resume(returning: islands)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }
}
