//
//  NetworkMonitor.swift
//  Seas_3
//
//  Created by Brian Romero on 10/18/24.
//

import Foundation
import Network

class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private var monitor: NWPathMonitor
    private(set) var isConnected: Bool = false
    
    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            self.isConnected = path.status == .satisfied
            NotificationCenter.default.post(name: .networkStatusChanged, object: nil, userInfo: ["isConnected": self.isConnected])
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
