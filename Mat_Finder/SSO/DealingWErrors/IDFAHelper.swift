//  IDFAHelper.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import AppTrackingTransparency
import AdSupport
import FirebaseAnalytics


@MainActor
class IDFAHelper {

    /// Requests IDFA permission and logs the result.
    static func requestIDFAPermission() async {
        if #available(iOS 14, *) {
            let status = await requestATT()
            print("ATT status: \(status.rawValue)")
            
            switch status {
            case .authorized:
                logIDFAAccessGranted()
                try? await IDFAAnalyticsHelper.configureTargetedAdvertising()
            case .denied:
                logIDFADenied()
            case .restricted:
                logIDFARestricted()
            case .notDetermined:
                print("IDFA Access Not Determined - requestIDFAPermission")
                Analytics.logEvent("idfa_access_not_determined - requestIDFAPermission", parameters: [:])
            @unknown default:
                print("Unknown ATT status")
            }
        } else {
            // iOS <14: always allowed
            logIDFAAccessGranted()
            try? await IDFAAnalyticsHelper.configureTargetedAdvertising()
        }
    }

    /// Async wrapper for ATT request
    @available(iOS 14, *)
    private static func requestATT() async -> ATTrackingManager.AuthorizationStatus {
        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Returns the IDFA if access is granted
    static func getIdfa() -> String? {
        if #available(iOS 14, *) {
            guard ATTrackingManager.trackingAuthorizationStatus == .authorized else {
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
