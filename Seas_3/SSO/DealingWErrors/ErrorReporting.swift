//
//  ErrorReporting.swift
//  Seas_3
//
//  Created by Brian Romero on 5/22/25.
//


import Foundation
import FirebaseCrashlytics

struct ErrorReporting {
    
    static func report(_ error: Error, message: String? = nil) {
        if let message = message {
            print("Error: \(message) - \(error.localizedDescription)")
        } else {
            print("Error: \(error.localizedDescription)")
        }
        
        // Send error to Crashlytics if available
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error)
        #endif
        
        // You could also add Sentry or other reporting here
    }
}
