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
    case overQueryLimit
    case invalidRequest
    case unknownError
    
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
        case .overQueryLimit: return "You have exceeded your query limit. Please try again later."
        case .invalidRequest: return "The request was invalid. Please check the address format or parameters."
        case .unknownError: return "An unknown error occurred."
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

let geocodingSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.protocolClasses = [LoggingURLProtocol.self]
    return URLSession(configuration: configuration)
}()


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

// Handle response status with additional validation
func handleResponseStatus(_ status: String, _ results: [GeocodingResponse.Result]) throws -> (latitude: Double, longitude: Double) {
    switch status {
    case "OK":
        if !results.isEmpty {
            // Adding validation step for geometry and location data
            if let location = results.first?.geometry?.location {
                let latitude = location.lat
                let longitude = location.lng
                return (latitude: latitude, longitude: longitude)
            } else {
                os_log("Geocoding returned empty geometry or location data", log: GeocodingLogger.geocoding, type: .error)
                throw GeocodingError.invalidResponseFormat
            }
        } else {
            throw GeocodingError.addressNotFound
        }
    case "ZERO_RESULTS":
        throw GeocodingError.addressNotFound
    case "REQUEST_DENIED":
        throw GeocodingError.requestDenied
    case "OVER_QUERY_LIMIT":
        throw GeocodingError.overQueryLimit
    case "INVALID_REQUEST":
        throw GeocodingError.invalidRequest
    case "UNKNOWN_ERROR":
        throw GeocodingError.unknownError
    default:
        throw GeocodingError.invalidResponse
    }
}




// Construct URL for geocoding request
func constructUrl(_ address: String, apiKey: String) throws -> URL {
    var components = URLComponents(string: GeocodingConfig.baseUrl)
    components?.queryItems = [
        URLQueryItem(name: "address", value: address),
        URLQueryItem(name: "key", value: apiKey)
    ]
    guard let url = components?.url else {
        throw GeocodingError.invalidURL
    }
    return url
}



// Geocode address internal implementation with retry logic
func geocodeInternal(address: String, apiKey: String) async throws -> (latitude: Double, longitude: Double) {
    let maxAttempts = 3
    let delay: TimeInterval = 1.0
    var attempts = 0

    // Retry loop
    while attempts < maxAttempts {
        do {
            let url = try constructUrl(address, apiKey: apiKey)
            os_log("Making geocoding request to: %@", log: GeocodingLogger.geocoding, type: .info, url.absoluteString)

            let (data, response) = try await geocodingSession.data(from: url)

            // ✅ Combine the two unwraps into one
            guard let httpResponse = response as? HTTPURLResponse else {
                os_log("Invalid HTTPURLResponse", log: GeocodingLogger.geocoding, type: .error)
                throw GeocodingError.invalidResponse
            }

            print("✅ HTTP Status Code: \(httpResponse.statusCode)")

            let rawResponse = String(data: data, encoding: .utf8) ?? "❓ Could not decode response"
            print("📦 Raw API response:\n\(rawResponse)")

            guard httpResponse.statusCode == 200 else {
                os_log("Unexpected status code: %d", log: GeocodingLogger.geocoding, type: .error, httpResponse.statusCode)
                throw GeocodingError.invalidResponse
            }


            do {
                let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
                
                // Simplified: Directly check for valid geometry and return coordinates
                guard let location = decoded.results.first?.geometry?.location else {
                    os_log("Geocoding returned empty geometry or location data", log: GeocodingLogger.geocoding, type: .error)
                    throw GeocodingError.invalidResponseFormat
                }

                return (latitude: location.lat, longitude: location.lng)

            } catch {
                os_log("Error decoding geocoding response: %@", log: GeocodingLogger.geocoding, type: .error, error.localizedDescription)
                throw GeocodingError.invalidJSONFormat
            }
        } catch {
            attempts += 1
            if attempts < maxAttempts {
                os_log("Attempt %d failed: %@. Retrying in %.1f seconds...", log: GeocodingLogger.geocoding, type: .info, attempts, error.localizedDescription, delay)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) // Sleep for delay time
            } else {
                os_log("Failed to geocode address after %d attempts: %@", log: GeocodingLogger.geocoding, type: .error, attempts, error.localizedDescription)
                throw error // Throw the last error after max attempts
            }
        }
    }

    fatalError("Unexpected error in geocodeInternal") // Should never reach here due to retry logic
}


// Geocode address
func geocode(address: String, apiKey: String) async throws -> (latitude: Double, longitude: Double) {
    print("Geocode function called with address: \(address)")
    
    do {
        let coordinates = try await geocodeInternal(address: address, apiKey: apiKey)
        print("Received coordinates: \(coordinates)")
        return coordinates
    } catch {
        print("Error geocoding address: \(error)")
        os_log("Error geocoding address: %@", log: GeocodingLogger.geocoding, type: .error, error.localizedDescription)

        throw error
    }
}

// MARK: - Geocoding
public func geocodeAddress(_ address: String) async throws -> (latitude: Double, longitude: Double) {
    var attempts = 0
    let maxAttempts = 3
    let delay: TimeInterval = 1.0
    
    // Validate API key before proceeding with the request
    guard !GeocodingConfig.apiKey.isEmpty else {
        os_log("API key is missing", log: GeocodingLogger.geocoding, type: .error)
        throw GeocodingError.apiKeyMissing
    }
    
    while attempts < maxAttempts {
        do {
            os_log("Attempting to geocode address: %@", log: GeocodingLogger.geocoding, type: .info, address)
            print("Attempting to geocode address: \(address) (Attempt \(attempts + 1)/\(maxAttempts))")
            print("Using API key: \(GeocodingConfig.apiKey.prefix(5))... (truncated for security)")
            let response = try await geocode(address: address, apiKey: GeocodingConfig.apiKey)
            print("Geocoding API response: \(response)")
            return response
        } catch {
            attempts += 1
            if attempts < maxAttempts {
                print("Geocoding API error: \(error). Retrying in \(delay) seconds...")
                os_log("Geocoding API error: %@", log: GeocodingLogger.geocoding, type: .error, error.localizedDescription)

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else {
                print("Failed to geocode address after \(maxAttempts) attempts: \(address). Error: \(error)")
                if let apiError = error as? GeocodingError {
                    throw PirateIslandError.geocodingError(apiError.localizedDescription)
                } else {
                    throw PirateIslandError.geocodingError(error.localizedDescription)
                }
            }
        }
    }

    fatalError("Unexpected error in geocodeAddress")
}



struct GeocodingResponse: Codable {
    let status: String
    let results: [Result]
    
    struct Result: Codable {
        let geometry: Geometry?
        
        struct Geometry: Codable {
            let location: Location
        }
        
        struct Location: Codable {
            let lat: Double
            let lng: Double
        }
    }
}
