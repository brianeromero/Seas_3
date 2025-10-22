//
//  Notification+Names.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/9/25.
//

import Foundation

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let showToast = Notification.Name("showToast")
    static let contextSaved = Notification.Name("contextSaved")
    static let firebaseConfigured = Notification.Name("firebaseConfigured")
    static let signInLinkReceived = Notification.Name("signInLinkReceived")
    static let fcmTokenReceived = Notification.Name("FCMTokenReceived")
    static let didSyncPirateIslands = Notification.Name("didSyncPirateIslands")
}

