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
        // Check if the error is a Firestore error
        if errorCode == FirestoreErrorCode.permissionDenied.rawValue {
            errorMessage?.wrappedValue = "Missing or insufficient permissions."
        } else if errorCode == FirestoreErrorCode.unauthenticated.rawValue {
            errorMessage?.wrappedValue = "Authentication error."
        } else if errorCode == FirestoreErrorCode.invalidArgument.rawValue {
            errorMessage?.wrappedValue = "Invalid argument provided."
        } else {
            errorMessage?.wrappedValue = errorDescription
        }
    case .none:
        break
    }
}
