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

    func fetchPirateIslands() -> [PirateIsland] {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            // Handle error appropriately
            print("Failed to fetch pirate islands: \(error.localizedDescription)")
            return []
        }
    }
}
