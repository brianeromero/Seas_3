//
//  GeocodingUtility.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import CoreLocation

var lastRequestTime: Date?

func geocodeAddress(_ address: String, completion: @escaping (Result<(latitude: Double, longitude: Double), Error>) -> Void) {
    // Early return if address is empty
    guard !address.isEmpty else {
        let error = NSError(domain: "GeocodingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Address cannot be empty"])
        completion(.failure(error))
        return
    }

    // Check last request time for throttling
    if let lastRequestTime = lastRequestTime, Date().timeIntervalSince(lastRequestTime) < 60 {
        let timeToWait = Int(ceil(60 - Date().timeIntervalSince(lastRequestTime)))
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(timeToWait)) {
            geocodeAddress(address, completion: completion) // Retry the request after waiting
        }
        return
    }
    
    guard let apiKey = Bundle.main.infoDictionary?["GoogleMapsAPIKey"] as? String else {
        let error = NSError(domain: "GeocodingError", code: 2, userInfo: [NSLocalizedDescriptionKey: "API key not found"])
        completion(.failure(error))
        return
    }
    
    let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    let urlString = "https://maps.googleapis.com/maps/api/geocode/json?address=\(encodedAddress)&key=\(apiKey)"
    print("URL: \(urlString)") // Print the formatted URL
    
    guard let url = URL(string: urlString) else {
        let error = NSError(domain: "GeocodingError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
        completion(.failure(error))
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        // Update last request time regardless of success or failure
        lastRequestTime = Date()
        
        if let error = error {
            print("Error: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        guard let data = data else {
            let error = NSError(domain: "GeocodingError", code: 4, userInfo: [NSLocalizedDescriptionKey: "No data received"])
            completion(.failure(error))
            return
        }
        
        print("Response: \(String(data: data, encoding: .utf8) ?? "Unknown response")")
        
        do {
            // Safely unwrap JSON data
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw NSError(domain: "GeocodingError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
            }
            
            // Check the status of the response
            guard let status = json["status"] as? String, status == "OK" else {
                let errorMessage = (json["error_message"] as? String) ?? "Unknown error"
                let error = NSError(domain: "GeocodingError", code: 5, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                completion(.failure(error))
                return
            }
            
            // Parse results
            if let results = json["results"] as? [[String: Any]],
               let location = results.first?["geometry"] as? [String: Any],
               let coordinates = location["location"] as? [String: Double] {
                
                let latitude = coordinates["lat"] ?? 0.0
                let longitude = coordinates["lng"] ?? 0.0
                completion(.success((latitude: latitude, longitude: longitude)))
            } else {
                let error = NSError(domain: "GeocodingError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                completion(.failure(error))
            }
        } catch {
            print("JSON parsing error: \(error.localizedDescription)")
            let error = NSError(domain: "GeocodingError", code: 7, userInfo: [NSLocalizedDescriptionKey: "JSON parsing error"])
            completion(.failure(error))
        }
    }.resume()
}
