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

    func fetchPirateIslands(sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil, fetchLimit: Int? = nil) -> Result<[PirateIsland], Error> {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        if let fetchLimit = fetchLimit {
            fetchRequest.fetchLimit = fetchLimit
        }
        do {
            let pirateIslands = try viewContext.fetch(fetchRequest)
            return .success(pirateIslands)
        } catch {
            return .failure(error)
        }
    }
}
