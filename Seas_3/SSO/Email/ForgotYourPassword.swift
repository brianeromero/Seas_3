//
//  ForgotYourPassword.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
import SwiftUI
import CoreData

struct ForgotYourPasswordView: View {
    @Environment(\.managedObjectContext) private var viewContext // Inject Core Data context
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
        guard !email.isEmpty else {
            message = "Please enter your email address."
            return
        }

        // Use the shared utility function to fetch user by email
        if let userInfo = fetchUserInfo(byEmail: email, context: viewContext) {
            message = "A reset link has been sent to \(userInfo.email)."
            // Implement actual email sending logic here
        } else {
            message = "Email does not exist in our system. Please create an account."
        }
    }
}

struct ForgotYourPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        // Include an in-memory Core Data stack for preview purposes
        let context = PersistenceController.preview.container.viewContext
        return ForgotYourPasswordView().environment(\.managedObjectContext, context)
    }
}

