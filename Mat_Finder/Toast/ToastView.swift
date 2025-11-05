//
//  ToastView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/3/24.
//

import SwiftUI

struct ToastView: View {
    let message: String
    var type: ToastType

    // MARK: - ToastType Enum
    enum ToastType: String {
        case success
        case error
        case info
        case custom // For just a message, no specific icon

        var iconName: String? {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .custom: return nil
            }
        }

        var tintColor: Color {
            switch self {
            case .success, .error, .info, .custom:
                return .white
            }
        }

        var backgroundColor: Color {
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
                    .foregroundColor(type.tintColor)
            }
            Text(message)
                .font(.subheadline)
                .foregroundColor(type.tintColor)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(type.backgroundColor)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}
