//
//  ManuallyVerifyUser.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/26/24.
//

import Foundation
import SwiftUI
import FirebaseAuth
import CoreData

struct ManuallyVerifyUser: View {
    @State private var userId: String = ""
    @State private var successMessage: String?
    @State private var errorMessage: String?
    
    @StateObject var authViewModel = AuthViewModel.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Manually Verify User")
                .font(.title)
                .bold()
            
            TextField("Enter User ID or Email", text: $userId)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button(action: manuallyVerify) {
                Text("Verify User")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            if let successMessage = successMessage {
                Text(successMessage)
                    .foregroundColor(.green)
                    .padding(.top)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top)
            }
        }
        .padding()
    }
    
    private func manuallyVerify() {
        print("Verify User button pressed")

        guard !userId.isEmpty else {
            errorMessage = "User ID or Email cannot be empty."
            print("Error: User ID or Email is empty.")
            return
        }

        // Normalize the email
        let normalizedEmail = userId.lowercased()
        print("Normalized email: \(normalizedEmail)")
        
        Task {
            do {
                let verificationSuccessful = try await authViewModel.manuallyVerifyUser(email: normalizedEmail)
                if verificationSuccessful {
                    self.successMessage = "User manually verified successfully."
                    self.errorMessage = nil
                } else {
                    self.successMessage = nil
                    self.errorMessage = "User manual verification failed."
                }
            } catch {
                self.successMessage = nil
                self.errorMessage = "Failed to manually verify user: \(error.localizedDescription)"
            }
        }
    }
}

struct ManuallyVerifyUser_Previews: PreviewProvider {
    static var previews: some View {
        ManuallyVerifyUser()
    }
}
