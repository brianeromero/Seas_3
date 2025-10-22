//
//  ConfigLoader.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import GoogleSignInSwift
import GoogleSignIn

struct Config: Decodable {
    var FacebookSecret: String?
    var FacebookDisplayName: String?
    var SENDGRID_API_KEY: String?
    var GoogleClientID: String?
    var GoogleApiKey: String?
    var GoogleAppID: String?
    var DeviceCheckKeyID: String?
    var DeviceCheckTeamID: String?
}

class ConfigLoader {
    static func loadConfigValues() -> Config? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist") else {
            print("Config.plist file not found")
            return nil
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("Failed to load Config.plist")
            return nil
        }
        
        let config = try? PropertyListDecoder().decode(Config.self, from: data)

        // ❌ Commented out because Firebase provides clientID
        /*
        guard let googleClientID = loadGoogleClientID() else {
            print("GoogleClientID not found in GoogleService-Info.plist")
            return nil
        }

        var modifiedConfig = config
        modifiedConfig?.GoogleClientID = googleClientID
        */

        var modifiedConfig = config // Still needed for setting other values

        // ✅ Optional: Keep API_KEY and APP_ID loading if still used elsewhere
        let googleApiKey = loadGoogleApiKey() ?? modifiedConfig?.GoogleApiKey
        let googleAppID = loadGoogleAppID() ?? modifiedConfig?.GoogleAppID

        modifiedConfig?.GoogleApiKey = googleApiKey
        modifiedConfig?.GoogleAppID = googleAppID

        return modifiedConfig
    }

    // ❌ Commented out – GoogleClientID comes from FirebaseApp
    /*
    private static func loadGoogleClientID() -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistData = FileManager.default.contents(atPath: path) else {
            print("GoogleService-Info.plist not found")
            return nil
        }

        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] else {
            print("Failed to parse GoogleService-Info.plist")
            return nil
        }

        return plistDict["CLIENT_ID"] as? String ?? plistDict["GoogleClientID"] as? String
    }
    */

    private static func loadGoogleApiKey() -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistData = FileManager.default.contents(atPath: path) else {
            print("GoogleService-Info.plist not found")
            return nil
        }

        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] else {
            print("Failed to parse GoogleService-Info.plist")
            return nil
        }

        return plistDict["API_KEY"] as? String
    }

    private static func loadGoogleAppID() -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plistData = FileManager.default.contents(atPath: path) else {
            print("GoogleService-Info.plist not found")
            return nil
        }

        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] else {
            print("Failed to parse GoogleService-Info.plist")
            return nil
        }

        return plistDict["GOOGLE_APP_ID"] as? String
    }
}
