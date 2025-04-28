//
//  UnifiedEmailManager.swift
//  Seas_3
//
//  Created by Brian Romero on 10/10/24.
//

import Foundation
import Firebase
import FirebaseAuth
import CoreData

class UnifiedEmailManager {
    static let shared = UnifiedEmailManager(managedObjectContext: PersistenceController.shared.container.viewContext)
    
    private let managedObjectContext: NSManagedObjectContext
    private let firebaseEmailService = EmailService()
    private let sendGridEmailService = SendGridEmailService()
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    // Sends a Firebase password reset email
    func sendPasswordReset(to email: String, completion: @escaping (Bool) -> Void) {
        firebaseEmailService.sendPasswordResetEmail(to: email, completion: completion)
    }

    // Sends a Firebase email verification
    func sendEmailVerification(to email: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let auth = FirebaseAuth.Auth.auth()
                let user = auth.currentUser
                let success: ()? = try await user?.sendEmailVerification()
                completion(success != nil)
            } catch {
                completion(false)
            }
        }
    }



    // Sends verification token email
    func sendVerificationToken(to email: String, userName: String, password: String) async -> Bool {
        print("Sending verification token email (from sendVerificationToken)...")
        let subject = "Verify Your Account"
        let verificationToken = UUID().uuidString

        // Fetch or create UserInfo entity
        let userInfo = EmailUtility.fetchUserInfo(byEmail: email) ?? UserInfo(context: managedObjectContext)
        print("Object type: \(type(of: userInfo))")
        userInfo.email = email
        userInfo.userName = userName
        userInfo.verificationToken = verificationToken
        
        // Assign required fields directly
        userInfo.isVerified = false // Set default value for isVerified
        userInfo.name = userName    // Use userName as the name
        
        do {
            let hashPassword = HashPassword()
            let hashedPassword = try hashPassword.hashPasswordScrypt(password)
            userInfo.passwordHash = hashedPassword.hash // Corrected here
        } catch {
            print("Error hashing password: \(error)")
            return false
        }

        do {
            try managedObjectContext.save()
            print("UserInfo saved successfully.")
        } catch let saveError as NSError {
            print("Error saving context (sendVerificationToken): \(saveError), \(saveError.userInfo)")
            return false
        }

        let verificationLink = "http://mfinderbjj.rf.gd/verify.php?token=\(verificationToken)&email=\(email)"
        let content = """
        Dear \(userName),
        
        Click on the verification link below to verify your account setup:
        
        \(verificationLink)
        
        Need help? Contact us at support@matfinder.com.
        
        Best regards,
        The Mat Finder Team
        """
        return await sendCustomEmail(to: email, subject: subject, content: content)
    }

    
    // Sends a custom email using SendGrid
    func sendCustomEmail(to email: String, subject: String, content: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            sendGridEmailService.sendEmail(to: email, subject: subject, content: content) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // Verifies email token and sends combined verification and welcome email
    func verifyEmail(token: String, email: String, userName: String) async -> Bool {
        print("Verifying (from verifyEmail) email token...")
        print("Token: \(token), Email: \(email), UserName: \(userName)")
        // Fetch user from database
        guard let user = EmailUtility.fetchUserInfo(byEmail: email) else {
            print("User not found")
            return false
        }

        // Verify token
        if user.verificationToken == token {
            print("Token verified successfully.")

            // Check if user is already verified
            if user.isVerified {
                return true
            }

            // Activate account -         // Update user's isVerified status
            user.isVerified = true
            print("User's isVerified status updated to: \(user.isVerified)")

            do {
                try managedObjectContext.save()
                print("User verified and context saved successfully.")
            } catch let saveError as NSError {
                print("Error saving context (verifyEmail): \(saveError), \(saveError.userInfo)")
                return false
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
            let success = await sendCustomEmail(to: email, subject: subject, content: content)
            return success
        } else {
            print("Invalid verification token")
            return false
        }
    }
}
