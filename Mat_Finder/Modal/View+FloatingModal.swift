//
//  View+FloatingModal.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/24/25.
//

import Foundation
import SwiftUI

extension View {
    func floatingModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self

            if isPresented.wrappedValue {
                // Dimmed background
                Color.primary.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { isPresented.wrappedValue = false }

                // Modal card
                content()
                    .frame(maxWidth: 600, maxHeight: 600)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .padding()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut, value: isPresented.wrappedValue)
    }
}
