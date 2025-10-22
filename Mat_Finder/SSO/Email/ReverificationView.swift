//
//  ReverificationView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/26/24.
//

import Foundation
import SwiftUI
import FirebaseAuth

struct ReverificationView: View {
    @State private var verificationSent = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Reverify Your Email")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            if verificationSent {
                Text("A verification email has been sent to your registered email address.")
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: resendVerificationEmail) {
                Text("Send Verification Email")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(verificationSent) // Disable button if email was sent
            
            Spacer()
        }
        .padding()
    }

    private func resendVerificationEmail() {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You need to be logged in to resend the verification email."
            return
        }
        
        user.sendEmailVerification { error in
            if let error = error {
                errorMessage = "Error sending email: \(error.localizedDescription)"
            } else {
                verificationSent = true
                errorMessage = nil // Clear any previous errors
            }
        }
    }
}

struct ReverificationView_Previews: PreviewProvider {
    static var previews: some View {
        ReverificationView()
    }
}
