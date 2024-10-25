//
//  IDFAHelper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import AppTrackingTransparency
import AdSupport
import FirebaseAnalytics

class IDFAHelper {
    
    static func requestIDFAPermission() {
        // Check if the App Tracking Transparency authorization status has been determined
        if #available(iOS 14, *) {
            // Check the current authorization status
            let trackingStatus = ATTrackingManager.trackingAuthorizationStatus
            
            // Handle the various possible statuses
            switch trackingStatus {
            case .authorized:
                // Permission already granted
                let idfa = ASIdentifierManager.shared().advertisingIdentifier
                print("IDFA Access Granted: \(idfa)")
                Analytics.logEvent("idfa_access_granted", parameters: ["idfa": idfa.uuidString])
            case .denied:
                // Permission denied
                print("IDFA Access Denied")
                Analytics.logEvent("idfa_access_denied", parameters: [:])
            case .notDetermined:
                // Request permission if not determined
                requestIDFAPermissionAgain()
            case .restricted:
                // Restricted access (e.g., parental controls)
                print("IDFA Access Restricted")
                Analytics.logEvent("idfa_access_restricted", parameters: [:])
            @unknown default:
                print("Unknown IDFA tracking status")
            }
        } else {
            // For iOS versions below 14, automatically allow access
            let idfa = ASIdentifierManager.shared().advertisingIdentifier
            print("IDFA Access Granted (iOS < 14): \(idfa)")
            Analytics.logEvent("idfa_access_granted", parameters: ["idfa": idfa.uuidString])
        }
    }
    
    private static func requestIDFAPermissionAgain() {
        // Request permission again after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    // User granted permission
                    let idfa = ASIdentifierManager.shared().advertisingIdentifier
                    print("IDFA Access Granted: \(idfa)")
                    Analytics.logEvent("idfa_access_granted", parameters: ["idfa": idfa.uuidString])
                case .denied, .restricted:
                    // User denied permission
                    print("IDFA Access Denied")
                    Analytics.logEvent("idfa_access_denied", parameters: [:])
                case .notDetermined:
                    // User hasn't made a choice yet
                    print("IDFA Access Not Determined")
                    Analytics.logEvent("idfa_access_not_determined", parameters: [:])
                @unknown default:
                    print("Unknown IDFA tracking status")
                }
            }
        }
    }
    
    
    static func getIdfa() -> String? {
        if #available(iOS 14, *) {
            let trackingStatus = ATTrackingManager.trackingAuthorizationStatus
            guard trackingStatus == .authorized else {
                print("IDFA access denied or restricted")
                return nil
            }
        }
        
        return ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
}
