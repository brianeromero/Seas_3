//
//  ForgotYourPassword.swift
//  Seas_3
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
                .padding()
                .keyboardType(.emailAddress)
            
            Button(action: {
                resetPassword(for: email)
            }) {
                Text("Send Reset Link")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.isValidEmail ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!email.isValidEmail) // Disable if email is not valid
            
            // Display message to the user
            if !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
        .padding()
        .onAppear {
            emailManager = UnifiedEmailManager(managedObjectContext: viewContext)
        }
    }

    private func resetPassword(for email: String) {
        print("Email address: \(email)") // Log email address

        guard !email.isEmpty else {
            message = "Please enter your email address."
            return
        }

        // Assuming `EmailUtility.fetchUserInfo` checks if the user exists
        guard let _ = EmailUtility.fetchUserInfo(byEmail: email) else {
            message = "Email does not exist in our system. Please create an account."
            return
        }

        // Use UnifiedEmailManager to send the password reset email
        emailManager?.sendPasswordReset(to: email) { success in
            DispatchQueue.main.async {
                if success {
                    message = "A reset link has been sent to \(email)."
                } else {
                    message = "Error sending email. Please try again."
                }
            }
        }
    }
}

struct ForgotYourPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        return ForgotYourPasswordView().environment(\.managedObjectContext, context)
    }
}

extension String {
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
}
