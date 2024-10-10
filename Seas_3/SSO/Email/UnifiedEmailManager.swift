//
//  UnifiedEmailManager.swift
//  Seas_3
//
//  Created by Brian Romero on 10/10/24.
//

import Foundation
import CoreData

class UnifiedEmailManager {
    private let firebaseEmailService = EmailService()
    private let sendGridEmailService = SendGridEmailService()
    private let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    // Sends a Firebase password reset email
    func sendPasswordReset(to email: String, completion: @escaping (Bool) -> Void) {
        firebaseEmailService.sendPasswordResetEmail(to: email, completion: completion)
    }
    
    // Sends a Firebase email verification
    func sendEmailVerification(to email: String, completion: @escaping (Bool) -> Void) {
        firebaseEmailService.sendEmailVerification(to: email, completion: completion)
    }
    
    // Sends a custom email using SendGrid
    func sendCustomEmail(to email: String, subject: String, content: String, completion: @escaping (Bool) -> Void) {
        sendGridEmailService.sendEmail(to: email, subject: subject, content: content, completion: completion)
    }
    
    // Example of sending a welcome email using SendGrid
    func sendWelcomeEmail(to email: String, userName: String, completion: @escaping (Bool) -> Void) {
        let subject = "Welcome to Mat Finder!"
        let content = """
        Dear \(userName),
        
        Welcome to Mat Finder! We're thrilled to have you join our community.
        
        Explore our features, find your perfect match, and stay updated on the latest news.
        
        Need help? Contact us at support@matfinder.com.
        
        Best regards,
        The Mat Finder Team
        """
        sendCustomEmail(to: email, subject: subject, content: content, completion: completion)
    }
    
    // Sends verification token email
    func sendVerificationToken(to email: String, userName: String, completion: @escaping (Bool) -> Void) {
        let subject = "Verify Your Account"
        let verificationToken = UUID().uuidString
        
        // Fetch or create UserInfo entity
        let userInfo = EmailUtility.fetchUserInfo(byEmail: email) ?? UserInfo(context: managedObjectContext)
        userInfo.email = email
        userInfo.userName = userName
        userInfo.verificationToken = verificationToken
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        // Generate verification link
        let verificationLink = "https://example.com/verify-email?token=\(verificationToken)&email=\(email)"
        
        let content = """
        Dear \(userName),
        
        Click on the verification link below to verify your account setup:
        
        \(verificationLink)
        
        Need help? Contact us at support@matfinder.com.
        
        Best regards,
        The Mat Finder Team
        """
        sendCustomEmail(to: email, subject: subject, content: content, completion: completion)
    }
    
    // Verifies email token
    func verifyEmail(token: String, email: String) {
        // Fetch user from database
        let user = EmailUtility.fetchUserInfo(byEmail: email)
        
        // Verify token
        if user?.verificationToken == token {
            // Activate account
            user?.isVerified = true
            try? managedObjectContext.save()
            // Send welcome email after verification
            sendWelcomeEmail(to: email, userName: user?.userName ?? "", completion: { success in
                print("Welcome email sent: \(success)")
            })
        } else {
            print("Invalid verification token")
        }
    }
    
    
    // Verifies email token
    func verifyEmail(token: String, email: String, completion: @escaping (Bool) -> Void) {
        // Fetch user from database
        guard let user = EmailUtility.fetchUserInfo(byEmail: email) else {
            print("User not found")
            completion(false)
            return
        }
        
        // Verify token
        if user.verificationToken == token {
            // Activate account
            user.isVerified = true
            do {
                try managedObjectContext.save()
                // Send welcome email after verification
                sendWelcomeEmail(to: email, userName: user.userName, completion: { success in
                    print("Welcome email sent: \(success)")
                    completion(true)
                })
            } catch {
                print("Error saving context: \(error.localizedDescription)")
                completion(false)
            }
        } else {
            print("Invalid verification token")
            completion(false)
        }
    }
}
