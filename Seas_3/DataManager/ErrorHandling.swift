//
//  ErrorHandling.swift
//  Seas_3
//
//  Created by Brian Romero on 9/30/24.
//

import Foundation
import SwiftUI

enum ErrorPresentation {
    case debug
    case user
    case none
}

func handleError(_ error: Error, context: String = "", presentation: ErrorPresentation = .debug) {
    switch presentation {
    case .debug:
        print("Error occurred: \(error.localizedDescription)")
        if !context.isEmpty {
            print("Error \(context): \(error.localizedDescription)")
        }
    case .user:
        // Display custom error message to the user
        // You can use SwiftUI's @State or @Binding to update an error message variable
        print("User-facing error: \(error.localizedDescription)")
    case .none:
        break
    }
}
