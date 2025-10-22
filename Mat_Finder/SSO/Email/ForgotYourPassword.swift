//
//  ForgotYourPassword.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import CoreData

struct ForgotYourPasswordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var emailManager: UnifiedEmailManager?

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
                resetPassword(for: email)
            }) {
                Text("Send Reset Link")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(email.isValidEmail ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!email.isValidEmail) // Disable if email is not valid
            
            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.top)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            emailManager = UnifiedEmailManager.shared
        }
    }

    private func resetPassword(for email: String) {
        guard !email.isEmpty else {
            message = "Please enter your email address."
            return
        }

        Task {
            if let _ = await EmailUtility.fetchUserInfo(byEmail: email) {
                emailManager?.sendPasswordReset(to: email) { success in
                    DispatchQueue.main.async {
                        if success {
                            message = "A reset link has been sent to \(email)."
                        } else {
                            message = "Error sending email. Please try again."
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    message = "Email does not exist in our system. Please create an account."
                }
            }
        }
    }
}

extension String {
    var isValidEmail: Bool {
        return ValidationUtility.validateEmail(self) == nil
    }
}
