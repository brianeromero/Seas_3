//
//  AppConfig.swift
//  Seas_3
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation

class AppConfig {
    static let shared = AppConfig()
    
    var facebookAppID: String?
    var googleClientID: String?
    var googleApiKey: String?
    var googleAppID: String?
    var sendgridApiKey: String?
    var deviceCheckKeyID: String?
    var deviceCheckTeamID: String?
    
    private init() {}
}
