//
//  Notification+Names.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/9/25.
//

import Foundation

extension Notification.Name {
    // ✅ Use consistent naming — UpperCamelCase
    static let networkStatusChanged = Notification.Name("NetworkStatusChanged")
    static let showToast = Notification.Name("ShowToast")
    static let hideToast = Notification.Name("HideToast") // <-- added for clarity
    static let contextSaved = Notification.Name("ContextSaved")
    static let firebaseConfigured = Notification.Name("FirebaseConfigured")
    static let signInLinkReceived = Notification.Name("SignInLinkReceived")
    static let fcmTokenReceived = Notification.Name("FCMTokenReceived")
    static let didSyncPirateIslands = Notification.Name("DidSyncPirateIslands")
}
