//
//  Logger.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation

struct Logger {
    static func log(_ message: String, view: String) {
        print("[\(view)] \(message)")
    }
}
