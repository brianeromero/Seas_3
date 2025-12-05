//
//  CountryService.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/15/24.
//

import Foundation
import Combine


enum CountryServiceError: Error, LocalizedError {
    case invalidURL
    case decodingError
    case googleAPIError
    case restCountriesAPIError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .decodingError: return "Error decoding country data"
        case .googleAPIError: return "Google API error"
        case .restCountriesAPIError: return "RestCountries API error"
        case .unknownError: return "Unknown error"
        }
    }
}

class CountryService: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = CountryService()
    
    @Published var countries: [Country] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let googleAPIKey: String? = ConfigLoader.loadConfigValues()?.GoogleApiKey
    
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Fetch Countries
    func fetchCountries() async {
        await MainActor.run { [weak self] in
            self?.isLoading = true
            self?.error = nil
        }

        // RestCountries API URL (specify fields)
        guard let url = URL(string: "https://restcountries.com/v3.1/all?fields=name,cca2,flags") else {
            await handleError(CountryServiceError.invalidURL)
            return
        }

        do {
            let (data, _) = try await session.data(from: url)
            
            // Decode as array of Country
            let fetchedCountries = try JSONDecoder().decode([Country].self, from: data)
            
            await updateCountries(fetchedCountries)
        } catch {
            print("RestCountries fetch failed: \(error)")
            // Try Google API as fallback
            await fetchCountriesFromGoogleAPI()
        }
    }

    // MARK: - Google API Fallback
    func fetchCountriesFromGoogleAPI() async {
        guard let apiKey = googleAPIKey else {
            await handleError(CountryServiceError.googleAPIError)
            return
        }
        
        guard let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=world&key=\(apiKey)") else {
            await handleError(CountryServiceError.invalidURL)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let countries = try parseGoogleAPIResponse(data: data)
            await updateCountries(countries)
        } catch {
            print("Google API fetch failed: \(error)")
            await handleError(error)
        }
    }

    private func parseGoogleAPIResponse(data: Data) throws -> [Country] {
        let response = try JSONDecoder().decode(GeocodingAPIResponse.self, from: data)
        return response.results.compactMap { result in
            guard let countryName = result.addressComponents.first(where: { $0.types.contains("country") })?.longName else { return nil }
            return Country(name: Country.Name(common: countryName), cca2: "", flag: "")
        }
    }

    // MARK: - Helpers
    private func updateCountries(_ countries: [Country]) async {
        await MainActor.run { [weak self] in
            self?.countries = countries.sorted { $0.name.common < $1.name.common }
            self?.isLoading = false
        }
    }

    private func handleError(_ error: Error) async {
        await MainActor.run { [weak self] in
            if error is URLError {
                self?.error = CountryServiceError.invalidURL
            } else if error is DecodingError {
                self?.error = CountryServiceError.decodingError
            } else if let countryError = error as? CountryServiceError {
                self?.error = countryError
            } else {
                self?.error = CountryServiceError.unknownError
            }
            self?.isLoading = false
        }
    }

    // MARK: - URLSession Delegate
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.host == "restcountries.com",
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    func getCountry(by name: String) -> Country? {
        countries.first { $0.name.common == name }
    }
}

// MARK: - Geocoding API Structures
struct GeocodingAPIResponse: Codable {
    let results: [GeocodingResult]
}

struct GeocodingResult: Codable {
    let addressComponents: [AddressComponent]
}

struct AddressComponent: Codable {
    let longName: String
    let types: [String]
    
    private enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case types
    }
}
