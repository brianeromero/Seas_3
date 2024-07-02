//
//  AppDayOfWeekRepository.swift
//  Seas_3
//
//  Created by Brian Romero on 6/25/24.
//

import Foundation
import CoreData

enum AppDayOfWeekRepositoryError: Error {
    case fetchError(String)
    case saveError(String)
    case deleteError(String)
}

class AppDayOfWeekRepository {
    static let shared = AppDayOfWeekRepository()

    private let context: NSManagedObjectContext

    private init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    func fetchAppDayOfWeek() throws -> [AppDayOfWeek] {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        do {
            let result = try context.fetch(fetchRequest)
            print("Fetched \(result.count) AppDayOfWeek objects.")
            return result
        } catch {
            let errorMessage = "Failed to fetch AppDayOfWeek: \(error.localizedDescription)"
            print(errorMessage)
            throw AppDayOfWeekRepositoryError.fetchError(errorMessage)
        }
    }

    func addAppDayOfWeek(name: String) throws {
        let newDayOfWeek = AppDayOfWeek(context: context)
        newDayOfWeek.name = name

        do {
            try context.save()
            print("AppDayOfWeek saved successfully.")
        } catch {
            let errorMessage = "Failed to save AppDayOfWeek: \(error.localizedDescription)"
            print(errorMessage)
            throw AppDayOfWeekRepositoryError.saveError(errorMessage)
        }
    }

    func deleteAppDayOfWeek(_ dayOfWeek: AppDayOfWeek) throws {
        context.delete(dayOfWeek)

        do {
            try context.save()
            print("AppDayOfWeek deleted successfully.")
        } catch {
            let errorMessage = "Failed to delete AppDayOfWeek: \(error.localizedDescription)"
            print(errorMessage)
            throw AppDayOfWeekRepositoryError.deleteError(errorMessage)
        }
    }

    func updateAppDayOfWeek(_ dayOfWeek: AppDayOfWeek, newName: String) throws {
        dayOfWeek.name = newName

        do {
            try context.save()
            print("AppDayOfWeek updated successfully.")
        } catch {
            let errorMessage = "Failed to update AppDayOfWeek: \(error.localizedDescription)"
            print(errorMessage)
            throw AppDayOfWeekRepositoryError.saveError(errorMessage)
        }
    }
}
