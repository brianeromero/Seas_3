//
//  Notification+Names.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/9/25.
//

import Foundation

extension Notification.Name {
    // Existing
    static let networkStatusChanged = Notification.Name("NetworkStatusChanged")
    static let showToast = Notification.Name("ShowToast")
    static let hideToast = Notification.Name("HideToast")
    static let contextSaved = Notification.Name("ContextSaved")
    static let firebaseConfigured = Notification.Name("FirebaseConfigured")
    static let signInLinkReceived = Notification.Name("SignInLinkReceived")
    static let fcmTokenReceived = Notification.Name("FCMTokenReceived")
    static let didSyncPirateIslands = Notification.Name("DidSyncPirateIslands")

    // Auth
    static let userLoggedOut = Notification.Name("UserLoggedOut")

    // 🧭 Navigation (OPTIONAL)
    static let navigateHome = Notification.Name("NavigateHome")

    // ✅ MatTime
    static let addNewMatTimeTapped = Notification.Name("AddNewMatTimeTapped")
}
