//
//  UserProfileViewModel.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import CoreData

class UserProfileViewModel: ObservableObject {
    @Published var userInfo: UserInfo?

    private let persistenceController = PersistenceController.shared

    func fetchData() {
        fetchData { [weak self] result in
            switch result {
            case .success(let userInfo):
                self?.userInfo = userInfo
            case .failure(let error):
                print("Error fetching UserInfo: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchData(completion: @escaping (Result<UserInfo?, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        
        do {
            let results = try context.fetch(request)
            completion(.success(results.first))
        } catch {
            completion(.failure(error))
        }
    }
}
