//
//  IDFAAnalyticsHelper.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/14/24.
//

import Foundation
import AppTrackingTransparency
import AdSupport
import AdServices
import FirebaseAnalytics
import GoogleMobileAds
import FBSDKCoreKit
import FirebaseFirestore
import CoreData

@MainActor
class IDFAAnalyticsHelper {
    
    // MARK: - Advertising and Analytics
    
    /// Delivers personalized ads using IDFA
    static func configureTargetedAdvertising() async throws {
        guard let idfa = IDFAHelper.getIdfa() else { return }

        // Pass IDFA to AdMob as a test device
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [idfa]
        
        // Save to Firestore
        try await Firestore.firestore().collection("advertising").document("targeted_ads").setData([
            "idfa": idfa
        ])

        // Cache in Core Data Stack
        let context = PersistenceController.shared.container.viewContext
        if let userInfo = try? await PersistenceController.shared.fetchSingle(entityName: "UserInfo") as? UserInfo {
            if userInfo.adSettings == nil {
                let adSettings = AdSettings(context: context)
                adSettings.enabled = true
                userInfo.adSettings = adSettings
            }
            userInfo.adSettings?.idfa = idfa
            try await PersistenceController.shared.saveContext()
        }
    }
    
    /// Measures ad effectiveness using IDFA
    static func trackAdAttribution() {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        Analytics.logEvent("ad_attribution", parameters: ["idfa": idfa])
    }
    
    /// Analyzes user behavior using IDFA
    static func trackUserBehavior() {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        Analytics.logEvent("user_behavior", parameters: ["idfa": idfa])
    }
    
    // MARK: - Tracking and Identification
    
    /// Links user behavior across sessions using IDFA
    static func identifyUser() async throws {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        
        let context = PersistenceController.shared.container.viewContext
        if let userInfo = try? await PersistenceController.shared.fetchSingle(entityName: "UserInfo") as? UserInfo {
            if userInfo.adSettings == nil {
                let adSettings = AdSettings(context: context)
                adSettings.enabled = true
                userInfo.adSettings = adSettings
            }
            userInfo.adSettings?.idfa = idfa
            try await PersistenceController.shared.saveContext()
        }
        
        try await Firestore.firestore().collection("users").document("user_idfa").setData([
            "idfa": idfa
        ])
    }
    
    /// Associates users across devices using IDFA
    static func trackCrossDevice() async throws {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        
        try await Firestore.firestore().collection("analytics").document("cross_device").setData([
            "idfa": idfa,
            "timestamp": Date()
        ])
        
        let context = PersistenceController.shared.container.viewContext
        if let userInfo = try? await PersistenceController.shared.fetchSingle(entityName: "UserInfo") as? UserInfo {
            if userInfo.adSettings == nil {
                let adSettings = AdSettings(context: context)
                adSettings.enabled = true
                userInfo.adSettings = adSettings
            }
            userInfo.adSettings?.idfa = idfa
            try await PersistenceController.shared.saveContext()
        }
    }
    
    // MARK: - Specific Use Cases
    
    /// Configures Facebook Ads using IDFA
    static func configureFacebookAds() {
        ATTrackingManager.requestTrackingAuthorization { status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    guard let idfa = IDFAHelper.getIdfa() else { return }
                    print("Facebook Ads configured with IDFA: \(idfa)")
                case .denied:
                    print("User denied IDFA access - configureFacebookAds")
                case .restricted:
                    print("IDFA access restricted- configureFacebookAds")
                case .notDetermined:
                    print("IDFA access not determined - configureFacebookAds")
                @unknown default:
                    print("Unexpected authorization status - configureFacebookAds")
                }
            }
        }
    }

    
    /// Configures Firebase Analytics using IDFA
    static func configureFirebaseAnalytics() {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        Analytics.setUserProperty(idfa, forName: "idfa")
    }
}
