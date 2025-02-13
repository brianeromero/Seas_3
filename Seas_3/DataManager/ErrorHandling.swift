//
//  ErrorHandling.swift
//  Seas_3
//
//  Created by Brian Romero on 9/30/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore

enum ErrorPresentation {
    case debug
    case user
    case none
}

func handleError(_ error: Error, context: String = "", presentation: ErrorPresentation = .debug, errorMessage: Binding<String?>? = nil) {
    let errorDescription = error.localizedDescription
    let errorCode = (error as NSError).code

    switch presentation {
    case .debug:
        print("Error occurred: \(errorDescription)")
        if !context.isEmpty {
            print("Context: \(context)")
        }
    case .user:
        switch errorCode {
        case 7: // Permission denied
            errorMessage?.wrappedValue = "log1: Missing or insufficient permissions."
        case 16: // Unauthenticated
            errorMessage?.wrappedValue = "log1: Authentication error."
        case 3: // Invalid argument
            errorMessage?.wrappedValue = "log1: Invalid argument provided."
        default:
            errorMessage?.wrappedValue = errorDescription
        }
    case .none:
        break
    }
}
