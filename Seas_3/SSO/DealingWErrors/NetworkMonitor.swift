//
//  NetworkMonitor.swift
//  Seas_3
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import Network



final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    private var currentStatus: NWPath.Status = .requiresConnection

    /// Thread-safe connectivity flag
    var isConnected: Bool {
        return currentStatus == .satisfied
    }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.currentStatus = path.status
            
            // Post on main thread so UI listeners don’t need to dispatch manually
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
