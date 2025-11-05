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
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.currentPath = path
            let newStatus = path.status == .satisfied
            let statusChanged = newStatus != self.isConnected
            
            DispatchQueue.main.async {
                self.isConnected = newStatus
                
                // Debug info
                print("""
                🌐 [NetworkMonitor] Path update:
                - Status: \(newStatus ? "✅ Connected" : "❌ Disconnected")
                - Expensive: \(path.isExpensive)
                - Constrained: \(path.isConstrained)
                - Interfaces: \(path.availableInterfaces.map { "\($0.type)" }.joined(separator: ", "))
                - Status changed: \(statusChanged)
                """)
                
                // Notify observers
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": newStatus]
                )
                
                // ✅ Use updated ToastThrottler
                if newStatus {
                    if self.hasShownNoInternetToast {
                        ToastThrottler.shared.postToast(
                            for: "network",
                            action: "restored",
                            type: .success,
                            isPersistent: false
                        )
                        self.hasShownNoInternetToast = false
                        print("🟢 [NetworkMonitor] Internet restored — queued 'Internet restored' toast")
                    }
                } else {
                    if !self.hasShownNoInternetToast {
                        ToastThrottler.shared.postToast(
                            for: "network",
                            action: "lost",
                            type: .info,
                            isPersistent: true
                        )
                        self.hasShownNoInternetToast = true
                        print("🚨 [NetworkMonitor] Internet lost — queued persistent 'No Internet' toast")
                    }
                }
            }
        }
        
        // Start monitoring
        monitor.start(queue: queue)
        print("🌐 [NetworkMonitor] Monitoring started.")
    }
}
