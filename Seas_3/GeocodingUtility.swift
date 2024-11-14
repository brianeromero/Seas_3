// GeocodingUtility.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
import Foundation
import CoreLocation
import os
import SwiftUI

enum GeocodingLogger {
    static let geocoding = OSLog(subsystem: "MF-inder.Seas-3", category: "GeocodingUtility")
}

// Geocoding errors
enum GeocodingError: Int, LocalizedError, Error {
    case invalidAddress
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case invalidJSONFormat
    case invalidResponseFormat
    case requestDenied
    case addressNotFound
    case unableToGeocodeAddress
    
    var localizedDescription: String {
        switch self {
        case .invalidAddress: return "Address cannot be empty"
        case .apiKeyMissing: return "API key not found"
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .invalidJSONFormat: return "Invalid JSON format"
        case .invalidResponseFormat: return "Invalid response format"
        case .requestDenied: return "Request denied"
        case .addressNotFound: return "Address not found"
        case .unableToGeocodeAddress: return "Unable to geocode address"
        }
    }
}

var lastRequestTime: Date?

/// Geocoding configuration
struct GeocodingConfig {
    static let apiKey = Bundle.main.infoDictionary?["GoogleMapsAPIKey"] as? String ?? ""
    static let baseUrl = "https://maps.googleapis.com/maps/api/geocode/json"
    
    /// Validate API key
    static func validateApiKey() throws {
        guard !apiKey.isEmpty else {
            throw GeocodingError.apiKeyMissing
        }
    }
}

// Create error from GeocodingError
func createError(_ error: GeocodingError) -> Error {
    NSError(domain: "GeocodingError", code: error.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
}

// Parse JSON data
func parseJSON(_ data: Data) throws -> [String: Any] {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw GeocodingError.invalidJSONFormat
    }
    return json
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
                throw GeocodingError.invalidResponseFormat
            }
        } else {
            throw GeocodingError.addressNotFound
        }
    case "ZERO_RESULTS":
        return (latitude: 0.0, longitude: 0.0)
    case "REQUEST_DENIED":
        throw GeocodingError.requestDenied
    default:
        throw GeocodingError.invalidResponse
    }
}

// Construct URL for geocoding request
func constructUrl(_ address: String) throws -> URL {
    let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    var urlComponents = URLComponents(string: GeocodingConfig.baseUrl)
    urlComponents?.queryItems = [URLQueryItem(name: "address", value: encodedAddress), URLQueryItem(name: "key", value: GeocodingConfig.apiKey)]
    guard let url = urlComponents?.url else {
        throw GeocodingError.invalidURL
    }
    return url
}

// Geocode address
func geocode(address: String, apiKey: String) async throws -> (latitude: Double, longitude: Double) {
    guard let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=\(address)&key=\(apiKey)") else {
        throw GeocodingError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("YourUserAgent", forHTTPHeaderField: "User-Agent")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        throw GeocodingError.invalidResponse
    }
    
    do {
        let json = try parseJSON(data)
        guard let status = json["status"] as? String else {
            throw GeocodingError.invalidJSONFormat
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
        os_log("Geocoding error: %@", log: GeocodingLogger.geocoding, error.localizedDescription)
        DispatchQueue.main.async {
            showAlert.wrappedValue = true
            alertMessage.wrappedValue = error.localizedDescription
        }
    }
}
