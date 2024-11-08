// GeocodingUtility.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.

import Foundation
import CoreLocation
import os
import SwiftUI
import CoreData

// Geocoding errors
enum GeocodingError: Int, Error {
    case invalidAddress
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case invalidJSONFormat
    case invalidResponseFormat
    case requestDenied
    case addressNotFound
    case unableToGeocodeAddress
}

let logger = Logger()
var lastRequestTime: Date?

/// Geocoding configuration
struct GeocodingConfig {
    static let apiKey = Bundle.main.infoDictionary?["GoogleMapsAPIKey"] as? String ?? ""
    static let baseUrl = "https://maps.googleapis.com/maps/api/geocode/json"
    
    /// Validate API key
    static func validateApiKey() throws {
        guard !apiKey.isEmpty else {
            throw createError(.apiKeyMissing)
        }
    }
}

// Create error from GeocodingError
func createError(_ error: GeocodingError) -> Error {
    let code = error.rawValue
    let message = errorCodeMessages[error] ?? "Unknown error"
    return NSError(domain: "GeocodingError", code: code, userInfo: [NSLocalizedDescriptionKey: message])
}

// Error code messages
let errorCodeMessages: [GeocodingError: String] = [
    .invalidAddress: "Address cannot be empty",
    .apiKeyMissing: "API key not found",
    .invalidURL: "Invalid URL",
    .invalidResponse: "Invalid response",
    .invalidJSONFormat: "Invalid JSON format",
    .invalidResponseFormat: "Invalid response format",
    .requestDenied: "Request denied",
    .addressNotFound: "Address not found",
    .unableToGeocodeAddress: "Unable to geocode address"
]

// Parse JSON data
func parseJSON(_ data: Data) throws -> [String: Any] {
    do {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw createError(.invalidJSONFormat)
        }
        return json
    } catch {
        throw createError(.invalidJSONFormat)
    }
}


// Handle response status
func handleResponseStatus(_ status: String, _ json: [String: Any]) throws -> (latitude: Double, longitude: Double) {
    switch status {
    case "OK":
        if let results = json["results"] as? [NSDictionary], !results.isEmpty {
            if let location = results.first?["geometry"] as? [String: Any],
               let coordinates = location["location"] as? [String: Double] {
                let latitude = coordinates["lat"] ?? 0.0
                let longitude = coordinates["lng"] ?? 0.0
                return (latitude: latitude, longitude: longitude)
            } else {
                throw createError(.invalidResponseFormat)
            }
        } else {
            throw createError(.addressNotFound)
        }
    case "ZERO_RESULTS":
        return (latitude: 0.0, longitude: 0.0)
    case "REQUEST_DENIED":
        throw createError(.requestDenied)
    default:
        throw createError(.invalidResponse)
    }
}

// Construct URL for geocoding request
func constructUrl(_ address: String) throws -> URL {
    let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    var urlComponents = URLComponents(string: GeocodingConfig.baseUrl)
    urlComponents?.queryItems = [URLQueryItem(name: "address", value: encodedAddress), URLQueryItem(name: "key", value: GeocodingConfig.apiKey)]
    guard let url = urlComponents?.url else {
        throw createError(.invalidURL)
    }
    return url
}

// Geocode address
func geocode(address: String, apiKey: String) async throws -> (latitude: Double, longitude: Double) {
    guard let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=\(address)&key=\(apiKey)") else {
        throw createError(.invalidURL)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("YourUserAgent", forHTTPHeaderField: "User-Agent")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        throw createError(.invalidResponse)
    }
    
    do {
        let json = try parseJSON(data)
        guard let status = json["status"] as? String else {
            throw createError(.invalidJSONFormat)
        }
        return try handleResponseStatus(status, json)
    } catch {
        throw error
    }
}


// Geocode Island Location
func geocodeIslandLocation(street: String, city: String, state: String, zip: String, showAlert: Binding<Bool>, alertMessage: Binding<String>) async {
    let fullAddress = "\(street), \(city), \(state) \(zip)"
    print("Geocoding Island Location: \(fullAddress)")
    
    do {
        let coordinates = try await geocode(address: fullAddress, apiKey: GeocodingConfig.apiKey)
        print("Geocoded coordinates: \(coordinates)")
        // Update latitude and longitude fields if needed
    } catch {
        os_log("Geocoding error: %@", log: .default, type: .error, error.localizedDescription)
        DispatchQueue.main.async {
            showAlert.wrappedValue = true
            alertMessage.wrappedValue = "Failed to geocode address"
        }
    }
}
