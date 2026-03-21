//
//  AppUpgradeManager.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/21/26.
//

import SwiftUI

final class AppUpgradeManager {
    static let shared = AppUpgradeManager()

    private var hasHandledUpgrade = false   // ✅ THIS WAS MISSING

    func handleAppUpgrade() {
        guard !hasHandledUpgrade else { return }
        hasHandledUpgrade = true

        let defaults = UserDefaults.standard
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let lastVersion = defaults.string(forKey: "app_version")

        if lastVersion == nil {
            // First install — don't force resync
            defaults.set(currentVersion, forKey: "app_version")
            return
        }

        guard lastVersion != currentVersion else { return }
        
        print("🚀 App updated from \(lastVersion ?? "nil") to \(currentVersion ?? "unknown")")

        clearCachesIfNeeded()
        migrateIfNeeded()

        // ✅ Delay prevents race conditions with app startup + sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in
                self.forceResync()
            }
        }

        defaults.set(currentVersion, forKey: "app_version")
    }

    private func clearCachesIfNeeded() {
        URLCache.shared.removeAllCachedResponses()

        // 🔥 Important for your sync system
        UserDefaults.standard.removeObject(forKey: "hasCompletedInitialSync")
    }

    private func migrateIfNeeded() {
        // Only if needed
    }

    @MainActor
    private func forceResync() {
        FirestoreSyncManager.shared.forceFullResync(reason: "app_upgrade")
    }
}
