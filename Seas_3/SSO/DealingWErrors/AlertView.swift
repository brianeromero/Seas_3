//  AlertModifier.swift
//  Seas_3
//  Created by Brian Romero on 10/24/24.


import SwiftUI


// Reusable Alert Modifier

/// A reusable modifier for presenting alerts.
struct AlertModifier: ViewModifier {
    /// Binding to control alert presentation.
    @Binding var isPresented: Bool
    
    /// Alert title.
    let title: String
    
    /// Alert message.
    let message: String
    
    /// Dismiss button title.
    let dismissButtonTitle: String
    
    /// Action to perform on dismiss.
    let dismissAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert(isPresented: $isPresented) {
                Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text(dismissButtonTitle)) {
                        dismissAction()
                    }
                )
            }
    }
}


// View Extensions

extension View {
    /// Presents an alert with customizable title, message, and dismiss action.
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control alert presentation.
    ///   - title: Alert title.
    ///   - message: Alert message.
    ///   - dismissButtonTitle: Dismiss button title (default: "OK").
    ///   - dismissAction: Action to perform on dismiss (default: {}).
    func showAlert(isPresented: Binding<Bool>, title: String, message: String, dismissButtonTitle: String = "OK", dismissAction: @escaping () -> Void = {}) -> some View {
        self.modifier(AlertModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            dismissButtonTitle: dismissButtonTitle,
            dismissAction: dismissAction
        ))
    }
    
    /// Presents an error alert with a standardized title and customizable message.
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control alert presentation.
    ///   - message: Alert message.
    func showErrorAlert(isPresented: Binding<Bool>, message: String) -> some View {
        self.showAlert(isPresented: isPresented, title: "Error", message: message)
    }
}
