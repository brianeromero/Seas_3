//
//  ValidatedField.swift
//  Mat_Finder
//
//  Created by Brian Romero on 2/6/26.
//

import Foundation
import SwiftUI

struct ValidatedField<Content: View>: View {
    let isValid: Bool
    let errorMessage: String
    let showValidation: Bool
    let content: Content

    init(
        isValid: Bool,
        errorMessage: String,
        showValidation: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.isValid = isValid
        self.errorMessage = errorMessage
        self.showValidation = showValidation
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .validationStyle(isValid: isValid)

            if showValidation && !isValid {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    
}




extension View {
    func validationStyle(isValid: Bool) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
        )
    }
}
