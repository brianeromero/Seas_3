// ResetUserVerificationView.swift
// Seas_3
//
// Created by Brian Romero on 10/26/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import os.log

struct ResetUserVerificationView: View {
    @State private var userId: String = ""
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var isLoading = false
    private let emailService = EmailService()
    @State private var user: User?
    @State private var customToken: String?

    let logger = os.Logger(subsystem: "com.example.Seas_3", category: "ResetUserVerification")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Reset User Verification")
                .font(.title)
                .bold()

            TextField("Enter User ID or Email", text: $userId)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: userId) { newValue in
                    logger.info("User entered email: \(newValue)")
                }

            Button(action: fetchCustomToken) {
                Text("Reset Verification")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isLoading)
            }
            .padding(.horizontal)
            .simultaneousGesture(TapGesture()
                .onEnded {
                    logger.info("Reset Verification button clicked")
                }
            )

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

    private func resetVerification() {
        logger.info("Resetting verification")
        guard !isLoading, let user = user, !user.email.isEmpty else {
            logger.error("User email is empty or nil")
            errorMessage = "User email is empty or nil"
            isLoading = false
            return
        }

        isLoading = true

        // Validate email address
        if let error = ValidationUtility.validateField(user.email, type: .email) {
            logger.error("Invalid email: \(error)")
            errorMessage = error
            isLoading = false
            return
        }

        let functions = Functions.functions()
        let data = ["email": user.email]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            functions.httpsCallable("sendVerificationEmail").call(jsonData) { result, error in
                self.isLoading = false
                
                if let error = error as NSError? {
                    logger.error("Failed to send verification email: \(error), code: \(error.code), userInfo: \(error.userInfo)")
                    self.errorMessage = "Failed to send verification email: \(error.localizedDescription), code: \(error.code)"
                    return
                }
                
                if let resultData = result?.data as? [String: Any] {
                    self.successMessage = "Verification email sent successfully. Please check your inbox."
                    self.errorMessage = nil
                    logger.info("Verification email sent successfully with response data: \(resultData)")
                } else {
                    self.errorMessage = "Failed to process the response data"
                    logger.error("Failed to process the response data")
                }
            }
        } catch {
            logger.error("Error serializing JSON: \(error.localizedDescription)")
            self.errorMessage = "Error serializing JSON"
            isLoading = false
        }
    }

    private func fetchCustomToken() {
        logger.info("Fetching custom token")
        isLoading = true

        let functions = Functions.functions()
        let data = ["userId": userId]

        functions.httpsCallable("getCustomToken").call(data) { result, error in
            logger.info("Cloud Function executed: \(Date())")
            logger.info("Cloud Function response: \(String(describing: result))")
            
            self.isLoading = false

            if let error = error as NSError? {
                logger.error("Error fetching custom token: \(error), code: \(error.code)")
                self.errorMessage = "Error fetching custom token: \(error.localizedDescription), code: \(error.code)"
                return
            }
            
            guard let tokenData = result?.data as? [String: Any], let token = tokenData["token"] as? String else {
                logger.error("No token received")
                self.errorMessage = "No token received"
                return
            }

            logger.info("Custom token fetched successfully: \(token)")
            self.customToken = token
            self.signInWithCustomToken()
        }
    }
    
    private func signInWithCustomToken() {
        logger.info("Signing in with custom token: \(customToken ?? "nil")")
        guard let customToken = customToken else {
            logger.error("Custom token is nil")
            errorMessage = "Failed to fetch custom token"
            return
        }
        
        Auth.auth().signIn(withCustomToken: customToken) { authDataResult, error in
            if let error = error {
                logger.error("Error signing in: \(error.localizedDescription)")
                self.errorMessage = "Error signing in: \(error.localizedDescription)"
            } else {
                logger.info("Signed in successfully. User ID: \(Auth.auth().currentUser?.uid ?? "nil")")
                self.fetchAndResetVerification()
            }
        }
    }
    
    private func fetchAndResetVerification() {
        logger.info("Fetching and resetting verification for user ID: \(userId)")
        guard !userId.isEmpty else {
            handleError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User ID or Email cannot be empty."]),
                        context: "User ID or Email validation",
                        presentation: .user,
                        errorMessage: $errorMessage)
            return
        }

        let trimmedUserId = userId.trimmingCharacters(in: .whitespaces)
        logger.info("Trimmed user ID: \(trimmedUserId)")

        if let error = ValidationUtility.validateField(trimmedUserId, type: .email) {
            handleError(error as! Error,
                        context: "Invalid email",
                        presentation: .user,
                        errorMessage: $errorMessage)
            return
        }

        let db = Firestore.firestore()
        db.collection("users").whereField("email", isEqualTo: trimmedUserId).getDocuments { snapshot, error in
            if let error = error {
                handleError(error,
                            context: "Fetching user data",
                            presentation: .user,
                            errorMessage: $errorMessage)
                return
            }

            guard let documents = snapshot?.documents else {
                handleError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user found with this email."]),
                            context: "User data check",
                            presentation: .user,
                            errorMessage: $errorMessage)
                return
            }

            if let document = documents.first {
                do {
                    self.user = try document.data(as: User.self)
                    logger.info("User data fetched successfully: \(String(describing: self.user))")
                    self.resetVerification()
                } catch {
                    handleError(error,
                                context: "Parsing user data",
                                presentation: .user,
                                errorMessage: $errorMessage)
                }
            } else {
                handleError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user found with this email."]),
                            context: "User data check",
                            presentation: .user,
                            errorMessage: $errorMessage)
            }
        }
    }
}

struct ResetUserVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        ResetUserVerificationView()
    }
}
