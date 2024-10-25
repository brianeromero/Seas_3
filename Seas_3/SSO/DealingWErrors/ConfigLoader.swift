//
//  ConfigLoader.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation

struct Config: Decodable {
    let FacebookAppID: String?
    let FacebookClientToken: String?
    let FacebookSecret: String?
    let FacebookDisplayName: String?
    let SENDGRID_API_KEY: String?
    let GoogleClientID: String?
    let GoogleApiKey: String?
    let GoogleAppID: String?
    let DeviceCheckKeyID: String?
    let DeviceCheckTeamID: String?
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
        return config
    }
}
