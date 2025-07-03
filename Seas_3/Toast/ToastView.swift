//
//  ToastView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/3/24.
//

import SwiftUI

struct ToastView: View { // Renamed from CustomToastView for consistency with your existing file name
    let message: String
    var type: ToastType // Added type for customization

    enum ToastType {
        case success
        case error
        case info
        case custom // For just a message, no specific icon

        var iconName: String? {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .custom: return nil // No icon for a plain message
            }
        }

        var tintColor: Color {
            switch self {
            case .success: return .white // Changed to blue
            case .error: return .white
            case .info: return .white
            case .custom: return .white
            }
        }

        var backgroundColor: Color {
            // Background of the toast bubble
            switch self {
            case .success: return Color.blue.opacity(1.0)
            case .error: return Color.red.opacity(1.0)
            case .info: return Color.yellow.opacity(1.0)
            case .custom: return Color.green.opacity(1.0)
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if let icon = type.iconName {
                Image(systemName: icon)
                    .foregroundColor(type.tintColor) // Icon color
            }
            Text(message)
                .font(.subheadline)
                .foregroundColor(type.tintColor) // Text color
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(type.backgroundColor) // Background of the toast bubble
        .cornerRadius(10)
        .shadow(radius: 5) // Optional: Add a subtle shadow
        // No .onAppear for dismissal here, that's handled by the modifier
    }
}
