//
//  CountryService.swift
//  Seas_3
//
//  Created by Brian Romero on 11/15/24.
//

import Foundation

class CountryService {
    static let shared = CountryService()

    func fetchCountries(completion: @escaping ([Country]?) -> Void) {
        guard let url = URL(string: "https://restcountries.com/v3.1/all") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data {
                do {
                    let countries = try JSONDecoder().decode([Country].self, from: data)
                    completion(countries)
                } catch {
                    print("Error decoding countries: \(error)")
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }.resume()
    }
}
