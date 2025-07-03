//
//  ToastModifier.swift
//  Seas_3
//
//  Created by Brian Romero on 7/3/25.
//

import Foundation
import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var isPresenting: Bool
    let message: String
    let type: ToastView.ToastType // Use your ToastView's ToastType
    var duration: TimeInterval = 2.0
    var alignment: Alignment = .bottom // Where the toast appears

    func body(content: Content) -> some View {
        ZStack(alignment: alignment) { // Align the ZStack's content
            content // The original view this modifier is applied to

            if isPresenting {
                ToastView(message: message, type: type) // Use your refined ToastView
                    .transition(AnyTransition.opacity.animation(.easeOut(duration: 0.3))) // Fade in/out
                    .padding(.bottom, 100) // Adjust padding as needed for bottom alignment
                    .onAppear {
                        print("ToastModifier: Toast appeared with message: \(message)")
                        // Start a timer to dismiss the toast
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isPresenting = false
                                print("ToastModifier: Toast dismissed")
                            }
                        }
                    }
                    .zIndex(1) // Ensure it appears on top of other content
            }
        }
    }
}

// Convenience extension to make it easier to use (like AlertToast)
extension View {
    func showToast(
        isPresenting: Binding<Bool>,
        message: String,
        type: ToastView.ToastType = .custom, // Default to plain custom toast
        duration: TimeInterval = 2.0,
        alignment: Alignment = .bottom
    ) -> some View {
        self.modifier(
            ToastModifier(
                isPresenting: isPresenting,
                message: message,
                type: type,
                duration: duration,
                alignment: alignment
            )
        )
    }
}
