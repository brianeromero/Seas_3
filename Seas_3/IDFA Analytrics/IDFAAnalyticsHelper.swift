//
//  IDFAAnalyticsHelper.swift
//  Seas_3
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
import CoreData // Ensure Core Data is imported


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
        
        // Log ad attribution events
        Analytics.logEvent("ad_attribution", parameters: ["idfa": idfa])
    }
    
    /// Analyzes user behavior using IDFA
    static func trackUserBehavior() {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        
        // Log user behavior events
        Analytics.logEvent("user_behavior", parameters: ["idfa": idfa])
    }
    
    // MARK: - Tracking and Identification
    
    /// Links user behavior across sessions using IDFA
    static func identifyUser() async throws {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        
        // Store IDFA in Core Data
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
        
        // Save to Firestore
        try await Firestore.firestore().collection("users").document("user_idfa").setData([
            "idfa": idfa
        ])
    }

    
    /// Associates users across devices using IDFA
    static func trackCrossDevice() async throws {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        
        // Log cross-device events in Firestore
        try await Firestore.firestore().collection("analytics").document("cross_device").setData([
            "idfa": idfa,
            "timestamp": Date()
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

    
    // MARK: - Specific Use Cases
    
    /// Configures Facebook Ads using IDFA
    static func configureFacebookAds() {
        ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
            switch status {
            case .authorized:
                guard let idfa = IDFAHelper.getIdfa() else { return }
                
                // Configure Facebook Ads
                print("Facebook Ads configured with IDFA: \(idfa)")
            case .denied:
                print("User denied IDFA access")
            case .restricted:
                print("IDFA access restricted")
            case .notDetermined:
                print("IDFA access not determined")
            @unknown default:
                print("Unexpected authorization status")
            }
        })
    }
    
    /// Configures Firebase Analytics using IDFA
    static func configureFirebaseAnalytics() {
        guard let idfa = IDFAHelper.getIdfa() else { return }
        
        // Set IDFA in Firebase Analytics
        Analytics.setUserProperty(idfa, forName: "idfa")
    }
}
