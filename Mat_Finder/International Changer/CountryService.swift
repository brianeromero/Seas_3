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
        case .invalidURL:
            return "Invalid URL"
        case .decodingError:
            return "Error decoding data"
        case .googleAPIError:
            return "Google API error"
        case .restCountriesAPIError:
            return "Rest Countries API error"
        case .unknownError:
            return "Unknown error"
        }
    }
}

class CountryService: NSObject, ObservableObject, URLSessionDelegate {
    static let shared = CountryService()
    
    @Published var countries: [Country] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    // Load Google API Key from Config.plist
    private let googleAPIKey: String? = ConfigLoader.loadConfigValues()?.GoogleApiKey
    
    lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    func fetchCountries() async {
        await MainActor.run { [weak self] in
            self?.isLoading = true
        }
        
        // Try fetching from restcountries.com
        guard let url = URL(string: "https://restcountries.com/v3.1/all") else {
            await MainActor.run { [weak self] in
                self?.error = URLError(.badURL)
                self?.isLoading = false
            }
            await fetchCountriesFromGoogleAPI() // Call Google API if RestCountries API fails
            return
        }

        do {
            let (data, _) = try await session.data(from: url)
            let fetchedCountries = try JSONDecoder().decode([Country].self, from: data)
            await MainActor.run { [weak self] in
                self?.countries = fetchedCountries.sorted { $0.name.common < $1.name.common }
                self?.isLoading = false
            }
        } catch {
            await MainActor.run { [weak self] in
                if error is DecodingError {
                    self?.error = CountryServiceError.decodingError
                } else if error is URLError {
                    self?.error = CountryServiceError.invalidURL
                } else {
                    self?.error = CountryServiceError.unknownError
                }
                self?.isLoading = false
            }
            await fetchCountriesFromGoogleAPI() // Call Google API if RestCountries API fails
        }
    }
    
    func fetchCountriesFromGoogleAPI() async {
        guard let apiKey = googleAPIKey else {
            await handleError(CountryServiceError.unknownError)
            return
        }

        guard let url = constructGoogleAPIURL(apiKey: apiKey) else {
            await handleError(CountryServiceError.invalidURL)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let countries = try parseGoogleAPIResponse(data: data)
            await updatePublishedProperties(countries: countries)
        } catch {
            await handleError(error)
        }
    }

    private func constructGoogleAPIURL(apiKey: String) -> URL? {
        return URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=world&key=\(apiKey)")
    }

    private func parseGoogleAPIResponse(data: Data) throws -> [Country] {
        let response = try JSONDecoder().decode(GeocodingAPIResponse.self, from: data)
        return response.results.compactMap { result -> Country? in
            guard let countryName = result.addressComponents.first(where: { $0.types.contains("country") })?.longName else { return nil }
            return Country(name: Country.Name(common: countryName), cca2: "", flag: "")
        }
    }

    private func updatePublishedProperties(countries: [Country]) async {
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
            } else if let countryServiceError = error as? CountryServiceError {
                self?.error = countryServiceError
            } else {
                self?.error = CountryServiceError.unknownError
            }
            self?.isLoading = false
        }
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.host == "restcountries.com" {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

        func getCountry(by name: String) -> Country? {
            return countries.first { $0.name.common == name }
        }
    }

    // Define Geocoding API response structure
    struct GeocodingAPIResponse: Codable {
        let results: [GeocodingResult]
    }

    struct GeocodingResult: Codable {
        let addressComponents: [AddressComponent]
    }

    struct AddressComponent: Codable {
        let longName: String
        let types: [String]
    }
