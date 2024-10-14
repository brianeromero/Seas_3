//
//  EmailService.swift
//  Seas_3
//
//  Created by Brian Romero on 10/9/24.
//

import Foundation
import Firebase
import FirebaseAuth
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
    func sendEmailVerification(to email: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().currentUser?.sendEmailVerification { error in
            if let error = error {
                print("Firebase verification email error: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Email verification sent successfully using Firebase.")
                self.updateVerificationStatus(for: email) // Update verification status
                completion(true)
            }
        }
    }
    
    // Updates the verification status in Core Data
    private func updateVerificationStatus(for email: String) {
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let users = try managedObjectContext.fetch(request)
            if let user = users.first {
                user.isVerified = true
                try managedObjectContext.save()
            }
        } catch {
            print("Error updating user verification status: \(error.localizedDescription)")
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
        // ...
        completion(true) // Replace with actual success/failure logic
    }
}
