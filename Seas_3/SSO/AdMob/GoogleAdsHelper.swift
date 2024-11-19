//
//  GoogleAdsHelper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation

class GoogleAdsHelper {
    
    /// Retrieves the Google Ads ID from the GoogleService-Info.plist file.
    static func getGoogleAdsID() -> String? {
        // Get the file path for GoogleService-Info.plist
        guard let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("GoogleService-Info.plist file not found.")
            return nil
        }

        // Load the data from the file
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("Failed to load data from GoogleService-Info.plist.")
            return nil
        }

        // Define a struct to hold the Google Service Info
        struct GoogleServiceInfo: Decodable {
            let ADMOB_APP_ID: String?
        }

        // Decode the data into the GoogleServiceInfo struct
        guard let googleServiceInfo = try? PropertyListDecoder().decode(GoogleServiceInfo.self, from: data) else {
            print("Failed to parse GoogleService-Info.plist.")
            return nil
        }

        // Return the Google Ads ID
        return googleServiceInfo.ADMOB_APP_ID
    }
}
