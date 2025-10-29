// ResetUserVerificationView.swift
// Mat_Finder
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
    private let emailService = EmailService(managedObjectContext: PersistenceController.shared.viewContext)
    @State private var user: User?
    @State private var customToken: String?

    let logger = OSLog(subsystem: "MF-inder.Seas-3", category: "ResetUserVerification")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Reset User Verification")
                .font(.title)
                .bold()

            TextField("Enter User ID or Email", text: $userId)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: userId) { oldValue, newValue in
                    os_log("User changed email from %@ to %@", log: logger, oldValue, newValue)
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
                    os_log("Reset Verification button clicked", log: logger)
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
        os_log("Resetting verification", log: logger)
        guard !isLoading, let user = user, !user.email.isEmpty else {
            os_log("User email is empty or nil", log: logger)
            errorMessage = "User email is empty or nil"
            isLoading = false
            return
        }

        isLoading = true

        // Validate email address
        if let error = ValidationUtility.validateEmail(user.email) {
            os_log("Invalid email: %@", log: logger, error.rawValue)
            errorMessage = error.rawValue
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
                    os_log("Failed to send verification email: %@, code: %d, userInfo: %@", log: logger, error.localizedDescription, error.code, error.userInfo)
                    self.errorMessage = "Failed to send verification email: \(error.localizedDescription), code: \(error.code)"
                    return
                }
                
                if let resultData = result?.data as? [String: Any] {
                    self.successMessage = "Verification email sent successfully. Please check your inbox."
                    self.errorMessage = nil
                    os_log("Verification email sent successfully with response data: %@", log: logger, resultData)
                } else {
                    self.errorMessage = "Failed to process the response data"
                    os_log("Failed to process the response data", log: logger)
                }
            }
        } catch {
            os_log("Error serializing JSON: %@", log: logger, error.localizedDescription)
            self.errorMessage = "Error serializing JSON"
            isLoading = false
        }
    }

    private func fetchCustomToken() {
        os_log("Fetching custom token", log: logger)
        isLoading = true

        let functions = Functions.functions()
        let data = ["userId": userId]

        functions.httpsCallable("getCustomToken").call(data) { result, error in
            os_log("Cloud Function executed: %@", log: logger, "\(Date())")
            os_log("Cloud Function response: %@", log: logger, String(describing: result))
            
            self.isLoading = false

            if let error = error as NSError? {
                os_log("Error fetching custom token: %@, code: %d", log: logger, error.localizedDescription, error.code)
                self.errorMessage = "Error fetching custom token: \(error.localizedDescription), code: \(error.code)"
                return
            }
            
            guard let tokenData = result?.data as? [String: Any], let token = tokenData["token"] as? String else {
                os_log("No token received", log: logger)
                self.errorMessage = "No token received"
                return
            }

            os_log("Custom token fetched successfully: %@", log: logger, token)
            self.customToken = token
            self.signInWithCustomToken()
        }
    }
    
    private func signInWithCustomToken() {
        os_log("Signing in with custom token: %@", log: logger, customToken ?? "nil")
        guard let customToken = customToken else {
            os_log("Custom token is nil", log: logger)
            errorMessage = "Failed to fetch custom token"
            return
        }
        
        Auth.auth().signIn(withCustomToken: customToken) { authDataResult, error in
            if let error = error {
                os_log("Error signing in: %@", log: logger, error.localizedDescription)
                self.errorMessage = "Error signing in: \(error.localizedDescription)"
            } else {
                os_log("Signed in successfully. User ID: %@", log: logger, Auth.auth().currentUser?.uid ?? "nil")
                self.fetchAndResetVerification()
            }
        }
    }
    
    private func fetchAndResetVerification() {
        os_log("Fetching and resetting verification for user ID: %@", log: logger, userId)
        guard !userId.isEmpty else {
            handleError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User ID or Email cannot be empty."]),
                        context: "User ID or Email validation",
                        presentation: .user,
                        errorMessage: $errorMessage)
            return
        }

        let trimmedUserId = userId.trimmingCharacters(in: .whitespaces)
        os_log("Trimmed user ID: %@", log: logger, trimmedUserId)

        if let error = ValidationUtility.validateEmail(trimmedUserId) {
            handleError(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error.rawValue]),
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
                    os_log("User data fetched successfully: %@", log: logger, String(describing: self.user))
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
