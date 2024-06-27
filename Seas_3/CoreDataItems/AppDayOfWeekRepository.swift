//
//  AppDayOfWeekRepository.swift
//  Seas_3
//
//  Created by Brian Romero on 6/25/24.
//

import Foundation
import CoreData

class AppDayOfWeekRepository {
    static let shared = AppDayOfWeekRepository()

    private let context = PersistenceController.shared.container.viewContext

    func fetchAppDayOfWeek() throws -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()

        do {
            return try context.fetch(fetchRequest)
        } catch {
            throw error
        }
    }
}

