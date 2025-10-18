//
//  NetworkMonitor.swift
//  Seas_3
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    private var currentStatus: NWPath.Status = .requiresConnection

    /// Expose the most recent path (for debug/logging)
    private(set) var currentPath: NWPath?
    
    /// Optional: make reactive for SwiftUI if needed
    @Published private(set) var isConnected: Bool = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.currentPath = path
            self.currentStatus = path.status
            self.isConnected = (path.status == .satisfied)
            
            print("🌐 [NetworkMonitor] Path changed: \(path.status == .satisfied ? "✅ Connected" : "❌ Disconnected") at \(Date())")
            
            // Notify non-SwiftUI listeners
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: nil,
                    userInfo: ["isConnected": self.isConnected]
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
