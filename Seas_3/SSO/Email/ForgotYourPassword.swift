//
//  ForgotYourPassword.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI

struct ForgotYourPasswordView: View {
    @State private var email: String = ""
    @State private var message: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Reset Your Password")
                .font(.largeTitle)
            
            Text("Enter your email address and we will send you a link to reset your password.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            TextField("Email address", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            Button(action: {
                // Handle password reset logic here
                resetPassword(for: email)
            }) {
                Text("Send Reset Link")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if !message.isEmpty {
                Text(message)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Forgot Your Password")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func resetPassword(for email: String) {
        // Implement your password reset logic here (e.g., Firebase Auth, your backend API)
        // Here is a placeholder implementation
        if email.isEmpty {
            message = "Please enter your email address."
        } else {
            message = "A reset link has been sent to \(email)."
            // Add actual logic to send a reset email
        }
    }
}

struct ForgotYourPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotYourPasswordView()
    }
}
