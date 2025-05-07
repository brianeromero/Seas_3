//
//  EmailService.swift
//  Seas_3
//
//  Created by Brian Romero on 10/9/24.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import CoreData

class EmailService {
    let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.managedObjectContext = managedObjectContext
    }

    // Firebase Authentication: Sends a password reset email
    func sendPasswordResetEmail(to email: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("Firebase Authentication error: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Password reset email sent successfully using Firebase.")
                completion(true)
            }
        }
    }

    // Sends a Firebase email verification
    func sendEmailVerification(completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            print("No current user")
            completion(false)
            return
        }
        
        currentUser.sendEmailVerification { error in
            if let error = error {
                print("Firebase verification email error: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Email verification sent successfully using Firebase.");
                completion(true)
            }
        }
    }
    
    // Sends account creation confirmation email using a custom email service
    func sendAccountCreationConfirmationEmail(to email: String, userName: String, completion: @escaping (Bool) -> Void) {
        _ = "Welcome to Mat Finder!"
        _ = """
        Dear \(userName),
        
        Welcome to Mat Finder! We're thrilled to have you join our community.
        
        To verify your email address, please click on the verification link sent separately.
        
        Need help? Contact us at support@matfinder.com.
        
        Best regards,
        The Mat Finder Team
        """
        
        // Implement custom email service logic here
        // For example, you can use SendGrid or another email service provider to send the email.
        // Placeholder for actual email sending logic.
        
        print("Sending confirmation email to \(email)...")
        // If sending is successful, call completion(true), else completion(false)
        completion(true) // Replace with actual success/failure logic
    }
}
