//
//  Errors.swift
//  Seas_3
//
//  Created by Brian Romero on 9/30/24.
//

import Foundation
import SwiftUI

// Errors.swift
enum FetchError: LocalizedError {
    case failedToFetchMatTimes(Error)
    
    var errorDescription: String? {
        switch self {
        case .failedToFetchMatTimes(let error):
            return "Failed to fetch mat times: \(error.localizedDescription)"
        }
    }
}
