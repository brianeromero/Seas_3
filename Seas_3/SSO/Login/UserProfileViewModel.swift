//
//  UserProfileViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import CoreData

class UserProfileViewModel: ObservableObject {
    @Published var userInfo: UserInfo?

    private let persistenceController = PersistenceController.shared

    func fetchData() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()

        do {
            let results = try context.fetch(request)
            // Assuming you only want the first UserInfo object
            self.userInfo = results.first
        } catch {
            print("Error fetching UserInfo: \(error.localizedDescription)")
        }
    }
}
