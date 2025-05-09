//
//  ConfigLoader.swift
//  Seas_3
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

        // Load GoogleClientID separately from GoogleService-Info.plist
        guard let googleClientID = loadGoogleClientID() else {
            print("GoogleClientID not found in GoogleService-Info.plist")
            return nil
        }

        // Configure Google Sign-In with the loaded GoogleClientID
        configureGoogleSignIn(clientID: googleClientID)
        
        // Create a local modifiedConfig variable to avoid overlapping access
        var modifiedConfig = config
        modifiedConfig?.GoogleClientID = googleClientID
        
        // Optionally load other values from GoogleService-Info.plist (e.g., API keys)
        let googleApiKey = loadGoogleApiKey() ?? modifiedConfig?.GoogleApiKey
        let googleAppID = loadGoogleAppID() ?? modifiedConfig?.GoogleAppID
        
        // Now update modifiedConfig with the new values
        modifiedConfig?.GoogleApiKey = googleApiKey
        modifiedConfig?.GoogleAppID = googleAppID
        
        return modifiedConfig
    }

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

    private static func configureGoogleSignIn(clientID: String) {
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }

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
