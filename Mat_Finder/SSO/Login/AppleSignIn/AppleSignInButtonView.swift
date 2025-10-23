//
//  AppleSignInButtonView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/22/25.
//

import Foundation
import SwiftUI
import AuthenticationServices // Make sure to import this for ASAuthorization

struct AppleSignInButtonView: View {
    // Keep the original properties, but note the generic placeholder in the LoginForm
    // will now be the visual representation. You'll handle the completion logic
    // when the actual button is tapped.
    var onRequest: () -> Void
    var onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    var body: some View {
        Button {
            onRequest() // Call the request action
            // In a real app, you would initiate the Sign in with Apple flow here.
            // Since the code provided uses a different completion type (Result<Any, Error>),
            // we'll stick to the minimal look for the UI.
            
            // Placeholder call to match the LoginForm logic's expectation:
            // AuthViewModel.shared.signInWithApple()
            // The LoginForm placeholder closure already handles this, so we rely on the button action.
        } label: {
            Image(systemName: "apple.logo")
                .resizable()
                .scaledToFit()
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
        }
        .frame(width: 50, height: 50)
        .background(Color.white)
        .cornerRadius(8)
    }
}
