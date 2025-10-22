//  IDFAHelper.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import AppTrackingTransparency
import AdSupport
import FirebaseAnalytics

class IDFAHelper {
    
    /// Requests IDFA permission and logs the result.
    static func requestIDFAPermission() {
        if #available(iOS 14, *) {
            let trackingStatus = ATTrackingManager.trackingAuthorizationStatus
            
            switch trackingStatus {
            case .authorized:
                logIDFAAccessGranted()
            case .denied:
                logIDFADenied()
            case .notDetermined:
                requestIDFAPermissionAgain()
            case .restricted:
                logIDFARestricted()
            @unknown default:
                print("Unknown IDFA tracking status")
            }
        } else {
            logIDFAAccessGranted()
        }
    }
    
    private static func requestIDFAPermissionAgain() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    logIDFAAccessGranted()
                case .denied, .restricted:
                    logIDFADenied()
                case .notDetermined:
                    print("IDFA Access Not Determined")
                    Analytics.logEvent("idfa_access_not_determined", parameters: [:])
                @unknown default:
                    print("Unknown IDFA tracking status")
                }
            }
        }
    }
    
    /// Returns the IDFA if access is granted.
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
    
    private static func logIDFAAccessGranted() {
        let idfa = ASIdentifierManager.shared().advertisingIdentifier
        guard idfa.uuidString != "00000000-0000-0000-0000-000000000000" else {
            print("IDFA Access Granted with zeroed ID")
            return
        }
        
        print("IDFA Access Granted: \(idfa)")
        Analytics.logEvent("idfa_access_granted", parameters: ["idfa": idfa.uuidString])
    }
    
    private static func logIDFADenied() {
        print("IDFA Access Denied")
        Analytics.logEvent("idfa_access_denied", parameters: [:])
    }
    
    private static func logIDFARestricted() {
        print("IDFA Access Restricted")
        Analytics.logEvent("idfa_access_restricted", parameters: [:])
    }
}
