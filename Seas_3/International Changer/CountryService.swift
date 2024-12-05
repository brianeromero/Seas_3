//
//  CountryService.swift
//  Seas_3
//
//  Created by Brian Romero on 11/15/24.
//

import Foundation
import Combine

class CountryService: ObservableObject {
    static let shared = CountryService()
    
    @Published var countries: [Country] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    func fetchCountries() async {
        await MainActor.run { [weak self] in
            self?.isLoading = true
        }
        
        guard let url = URL(string: "https://restcountries.com/v3.1/all") else {
            await MainActor.run { [weak self] in
                self?.error = URLError(.badURL)
                self?.isLoading = false
            }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fetchedCountries = try JSONDecoder().decode([Country].self, from: data)
            await MainActor.run { [weak self] in
                self?.countries = fetchedCountries.sorted { $0.name.common < $1.name.common }
                self?.isLoading = false
            }
        } catch {
            await MainActor.run { [weak self] in
                self?.error = error
                self?.isLoading = false
            }
        }
    }
}
