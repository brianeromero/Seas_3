//
//  ForgotYourPassword.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import Foundation
import SwiftUI
<<<<<<< HEAD
import CoreData

struct ForgotYourPasswordView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var emailManager: UnifiedEmailManager?
=======
import SwiftUI
import CoreData

struct ForgotYourPasswordView: View {
    @Environment(\.managedObjectContext) private var viewContext // Inject Core Data context
    @State private var email: String = ""
    @State private var message: String = ""
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9

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
<<<<<<< HEAD
                .padding()
                .keyboardType(.emailAddress)
=======
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
            
            Button(action: {
                resetPassword(for: email)
            }) {
                Text("Send Reset Link")
<<<<<<< HEAD
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

=======
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
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
        guard !email.isEmpty else {
            message = "Please enter your email address."
            return
        }

<<<<<<< HEAD
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
=======
        // Use the shared utility function to fetch user by email
        if let userInfo = fetchUserInfo(byEmail: email, context: viewContext) {
            message = "A reset link has been sent to \(userInfo.email)."
            // Implement actual email sending logic here
        } else {
            message = "Email does not exist in our system. Please create an account."
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
        }
    }
}

struct ForgotYourPasswordView_Previews: PreviewProvider {
    static var previews: some View {
<<<<<<< HEAD
=======
        // Include an in-memory Core Data stack for preview purposes
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
        let context = PersistenceController.preview.container.viewContext
        return ForgotYourPasswordView().environment(\.managedObjectContext, context)
    }
}

<<<<<<< HEAD
extension String {
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
}
=======
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
