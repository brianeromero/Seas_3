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
        let verificationLink = "http://mfinderbjj.rf.gd/verify.php?token=\(verificationToken)&email=\(email)"
        
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

    // Verifies email token and sends combined verification and welcome email
    func verifyEmail(token: String, email: String, userName: String, completion: @escaping (Bool) -> Void) {
        // Fetch user from database
        guard let user = EmailUtility.fetchUserInfo(byEmail: email) else {
            print("User not found")
            completion(false)
            return
        }

        // Verify token
        if user.verificationToken == token {
            // Check if user is already verified
            if user.isVerified {
                completion(true)
                return
            }
            
            // Activate account
            user.isVerified = true
            do {
                try managedObjectContext.save()
            } catch {
                print("Error saving context: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // Send combined verification and welcome email
            let subject = "Account Verified - Welcome to Mat Finder!"
            let content = """
            Dear \(userName),
            
            Congratulations! Your account has been successfully verified.
            
            Welcome to MF_inder or Mat Finder as we wish to be known! You're now ready to navigate Jiu-Jitsu gyms and open mats near you and all over. Be sure to share your favorite gyms and training schedules with friends!
            
            About MF_inder:
            MF_inder is a passion project created by a BJJ purple belt to help practitioners find training opportunities while traveling.
            
            Our Mission:
            Provide a free, community-driven platform for BJJ enthusiasts to share and discover open mats and gyms worldwide.
            
            Get Involved:
            Report bugs, share feedback, or suggest features at: mfinder.bjj@gmail.com
            
            Thank you for joining the MF_inder community!
            Best regards,
            MF_inder Team
            """
            sendCustomEmail(to: email, subject: subject, content: content, completion: { success in
                print("Verification and welcome email sent: \(success)")
                completion(true)
            })
        } else {
            print("Invalid verification token")
            completion(false)
        }
    }
}
