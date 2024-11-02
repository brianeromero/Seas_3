//
//  Errors.swift
//  Seas_3
//
//  Created by Brian Romero on 9/30/24.
//

import Foundation
import SwiftUI

// Network-related errors
enum NetworkServerError: LocalizedError {
    case failedToFetchData(Error)
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .failedToFetchData(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Error decoding data: \(error.localizedDescription)"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// Authentication-related errors
enum AuthenticationError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case accountLocked
    case invalidPasswordHash
    case invalidCredentials
    case networkError
    case serverError
    case coreDataError
    case unverifiedEmail
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Email not found. Please create an account."
        case .invalidPassword:
            return "Invalid password."
        case .accountLocked:
            return "Account locked due to excessive password attempts."
        case .invalidPasswordHash:
            return "Invalid password hash: "
        case .invalidCredentials:
            return "Invalid credentials."
        case .networkError:
            return "Network error."
        case .serverError:
            return "Server error."
        case .coreDataError:
            return "Core Data error."
        case .unverifiedEmail:
            return "Email is not verified."
        }
    }
}

// Signin-related errors
enum SignInError: String, LocalizedError {
    case invalidEmail = "Email not found. Please create an account."
    case invalidPassword = "Invalid password."
    case accountLocked = "Account locked due to excessive password attempts."
    case invalidPasswordHash = "Invalid password hash: "
    
    var errorDescription: String { rawValue }
}

// Core Data-related fetch errors
enum FetchError: LocalizedError {
    case failedToFetchMatTimes(Error)
    case failedToFetchAppDayOfWeek(Error)
    case failedToSaveContext(Error)
    
    var errorDescription: String? {
        switch self {
        case .failedToFetchMatTimes(let error):
            return "Failed to fetch MatTimes: \(error.localizedDescription)"
        case .failedToFetchAppDayOfWeek(let error):
            return "Failed to fetch AppDayOfWeek: \(error.localizedDescription)"
        case .failedToSaveContext(let error):
            return "Failed to save changes to the context: \(error.localizedDescription)"
        }
    }
}
