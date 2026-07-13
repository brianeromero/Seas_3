//
//  CountryService.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/15/24.
//

import Foundation
import Combine



enum CountryServiceError: Error, LocalizedError {
    case fileNotFound
    case decodingError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Countries.json could not be found."
        case .decodingError:
            return "Unable to decode Countries.json."
        case .unknownError:
            return "Unknown error loading countries."
        }
    }
}

final class CountryService: ObservableObject {

    static let shared = CountryService()

    @Published var countries: [Country] = []
    @Published var isLoading = false
    @Published var error: Error?

    private init() {}

    // MARK: - Load Countries

    func fetchCountries() async {

        if !countries.isEmpty {
            print("✅ Countries already loaded: \(countries.count)")
            return
        }

        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {

            guard let url = Bundle.main.url(forResource: "countries", withExtension: "json") else {
                print("❌ countries.json NOT FOUND")
                throw CountryServiceError.fileNotFound
            }

            print("✅ Found countries.json")

            let data = try Data(contentsOf: url)

            print("✅ JSON size: \(data.count) bytes")

            let fetchedCountries = try JSONDecoder().decode([Country].self, from: data)

            print("✅ Loaded \(fetchedCountries.count) countries")
            print("✅ First country: \(fetchedCountries.first?.name.common ?? "None")")

            await updateCountries(fetchedCountries)

            print("✅ CountryService now has \(countries.count) countries")
            
        } catch let decodingError as DecodingError {

            print("❌ Decoding Error:")
            print(decodingError)

            await handleError(CountryServiceError.decodingError)

        } catch {

            print("❌ Error:")
            print(error)

            await handleError(error)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func updateCountries(_ countries: [Country]) {
        self.countries = countries.sorted {
            $0.name.common.localizedCaseInsensitiveCompare($1.name.common) == .orderedAscending
        }

        self.isLoading = false
    }

    @MainActor
    private func handleError(_ error: Error) {
        self.error = error
        self.isLoading = false
    }

    func getCountry(by name: String) -> Country? {
        countries.first {
            $0.name.common.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}
