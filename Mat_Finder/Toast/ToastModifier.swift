//
//  ToastModifier.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/3/25.
//

import Foundation
import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var isPresenting: Bool
    let message: String
    let type: ToastView.ToastType
    var duration: TimeInterval = 2.0
    var alignment: Alignment // This now determines the base alignment
    var verticalOffset: CGFloat = 0 // <-- NEW: Add vertical offset parameter

    func body(content: Content) -> some View {
        // The ZStack's alignment controls where its *content* (including the ToastView) is aligned
        ZStack(alignment: alignment) {
            content // The original view this modifier is applied to

            if isPresenting {
                ToastView(message: message, type: type)
                    .transition(AnyTransition.opacity.animation(.easeOut(duration: 0.3))) // Fade in/out
                    // Adjust position based on alignment and offset
                    .offset(y: verticalOffset) // <-- NEW: Apply vertical offset
                    // Remove the fixed .padding(.bottom, 100) or adjust based on your new offset logic
                    // If alignment is .top, a positive offset moves it down.
                    // If alignment is .bottom, a negative offset moves it up.
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
        alignment: Alignment = .top, // <-- IMPORTANT: Change default to .top for easier offset management
        verticalOffset: CGFloat = 0 // <-- NEW: Add verticalOffset parameter
    ) -> some View {
        self.modifier(
            ToastModifier(
                isPresenting: isPresenting,
                message: message,
                type: type,
                duration: duration,
                alignment: alignment,
                verticalOffset: verticalOffset // Pass the new parameter
            )
        )
        // ✅ ADD THIS: The .onReceive listener directly to the modifier's result
        // This makes the modifier self-contained for listening and showing.
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowToast"))) { notification in
            if let userInfo = notification.userInfo,
               let _ = userInfo["message"] as? String,
               let typeString = userInfo["type"] as? String,
               let _ = ToastView.ToastType(rawValue: typeString) {

                isPresenting.wrappedValue = true // Directly set the binding
                if isPresenting.wrappedValue { // Only update if currently showing
                    // You might need to refine how you pass the message and type
                    // if you want this global listener to control *these specific* bindings.
                    // For now, let's assume the notification carries the primary message/type
                    // and the modifier's message/type properties are set via its init.
                    // For a global toast, you'd typically have the ToastModifier's init
                    // take these values and then update them via the binding, like this:
                    // (This requires a slight refactor of ToastModifier to accept message/type as @Binding as well,
                    // or you use a shared @StateObject/ObservableObject for toast state.)

                    // *** SIMPLER APPROACH FOR GLOBAL TOAST WITH MODIFIER ***
                    // Let the modifier's .onAppear handle the timer,
                    // and let the NotificationCenter directly update the @State in AppRootView
                    // which then feeds the modifier. So, you're back to the AppRootView
                    // .onReceive approach, but then apply the modifier *after* that.
                    // Let's revert to the previous advice for AppRootView's .onReceive,
                    // but fix the positioning in the modifier.
                }
            }
        }
    }
}
