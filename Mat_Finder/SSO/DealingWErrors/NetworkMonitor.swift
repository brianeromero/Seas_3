//
//  NetworkMonitor.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import Network
import Combine
import SwiftUI

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    @Published private(set) var isConnected: Bool = false
    private var hasShownNoInternetToast = false
    private(set) var currentPath: NWPath?

    private init() {
        print("🌐 [NetworkMonitor] Initializing...")

        // Handle path updates (including initial offline state)
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.currentPath = path
            
            let newStatus = path.status == .satisfied
            let statusChanged = (newStatus != self.isConnected)
            self.isConnected = newStatus
            
            // Detailed debug logging
            print("""
            🌐 [NetworkMonitor] Path update:
            - Status: \(newStatus ? "✅ Connected" : "❌ Disconnected")
            - Expensive: \(path.isExpensive)
            - Constrained: \(path.isConstrained)
            - Interfaces: \(path.availableInterfaces.map { "\($0.type)" }.joined(separator: ", "))
            - Previous isConnected: \(!statusChanged ? "No change" : "Changed")
            """)

            DispatchQueue.main.async {
                // Reactive network status notification
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": self.isConnected]
                )

                // Toast handling
                if newStatus {
                    // Internet restored
                    if self.hasShownNoInternetToast {
                        NotificationCenter.default.post(name: .hideToast, object: nil)
                        self.hasShownNoInternetToast = false
                        print("🟢 [NetworkMonitor] Internet restored — hiding toast")
                    }
                } else {
                    // Internet lost (including first offline state)
                    if !self.hasShownNoInternetToast {
                        NotificationCenter.default.post(
                            name: .showToast,
                            object: nil,
                            userInfo: [
                                "message": "No internet connection. Sync postponed until you're back online.",
                                "type": ToastView.ToastType.info.rawValue
                            ]
                        )
                        self.hasShownNoInternetToast = true
                        print("🚨 [NetworkMonitor] Internet lost — showing 'No Internet' toast")
                    }
                }
            }
        }

        // Start monitoring
        monitor.start(queue: queue)
        print("✅ [NetworkMonitor] NWPathMonitor started on queue: \(queue.label)")
    }

    deinit {
        monitor.cancel()
        print("🛑 [NetworkMonitor] Deinitialized and stopped monitoring")
    }
}
