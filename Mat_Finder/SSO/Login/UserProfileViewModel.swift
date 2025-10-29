//
//  UserProfileViewModel.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import CoreData

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var userInfo: UserInfo?

    private let persistenceController = PersistenceController.shared

    /// Public method to fetch data asynchronously
    func fetchData() async {
        do {
            self.userInfo = try await fetchUserInfo()
        } catch {
            print("Error fetching UserInfo: \(error.localizedDescription)")
        }
    }

    /// Private async method that performs Core Data fetch
    private func fetchUserInfo() async throws -> UserInfo? {
        let context = persistenceController.container.viewContext
        return try await context.perform {
            let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
            let results = try context.fetch(request)
            return results.first
        }
    }
}
