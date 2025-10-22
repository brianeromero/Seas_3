//
//  UnifiedEmailManager.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/10/24.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseAuth
import CoreData



@MainActor
class UnifiedEmailManager {
    static let shared = UnifiedEmailManager(managedObjectContext: PersistenceController.shared.container.viewContext)
    
    private let managedObjectContext: NSManagedObjectContext
    private let firebaseEmailService = EmailService()
    private let sendGridEmailService = SendGridEmailService()
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    // MARK: - Firebase password reset
    func sendPasswordReset(to email: String, completion: @escaping (Bool) -> Void) {
        firebaseEmailService.sendPasswordResetEmail(to: email, completion: completion)
    }

    // MARK: - Firebase email verification
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

    // MARK: - Verification token email
    func sendVerificationToken(to email: String, userName: String, password: String) async throws -> Bool {
        print("Sending verification token email...")

        let subject = "Verify Your Account"
        let verificationToken = UUID().uuidString
        let hasher = HashPassword()
        let hashedPassword = try hasher.hashPasswordScrypt(password)

        return try await withCheckedThrowingContinuation { continuation in
            managedObjectContext.perform {
                do {
                    let userInfo = UserInfo(context: self.managedObjectContext)

                    userInfo.email = email
                    userInfo.userName = userName
                    userInfo.verificationToken = verificationToken
                    userInfo.isVerified = false
                    userInfo.name = userName
                    userInfo.passwordHash = hashedPassword.hash
                    userInfo.salt = hashedPassword.salt
                    userInfo.iterations = Int64(hashedPassword.iterations)

                    try self.managedObjectContext.save()
                    print("✅ Saved user \(userName) with verification token")

                    let verificationLink = "http://mfinderbjj.rf.gd/verify.php?token=\(verificationToken)&email=\(email)"
                    let content = """
                    Dear \(userName),

                    Click the link below to verify your account:
                    \(verificationLink)

                    Need help? Contact support@matfinder.com.

                    Best,
                    The Mat Finder Team
                    """

                    Task {
                        let result = await self.sendCustomEmail(to: email, subject: subject, content: content)
                        continuation.resume(returning: result)
                    }
                } catch {
                    print("❌ Core Data save error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    
    // MARK: - Send custom email via SendGrid
    func sendCustomEmail(to email: String, subject: String, content: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            sendGridEmailService.sendEmail(to: email, subject: subject, content: content) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Verify email token and send welcome email
    func verifyEmail(token: String, email: String, userName: String) async -> Bool {
        print("Verifying email token for \(email)...")

        // Fetch user asynchronously
        guard let user = await EmailUtility.fetchUserInfo(byEmail: email) else {
            print("User not found")
            return false
        }

        // Verify token
        guard user.verificationToken == token else {
            print("Invalid verification token")
            return false
        }

        // Already verified?
        if user.isVerified {
            return true
        }

        // Update user's isVerified status
        user.isVerified = true
        print("User's isVerified status updated to: \(user.isVerified)")

        do {
            try managedObjectContext.save()
            print("User verified and context saved successfully.")
        } catch let saveError as NSError {
            print("Error saving context: \(saveError), \(saveError.userInfo)")
            return false
        }

        // Send welcome email
        let subject = "Account Verified - Welcome to Mat Finder!"
        let content = """
        Dear \(userName),
        
        Congratulations! Your account has been successfully verified.
        
        Welcome to Mat_Finder! You're now ready to navigate Jiu-Jitsu gyms and open mats near you and all over. Share your favorite gyms and training schedules with friends!
        
        About Mat_Finder:
        Mat_Finder is a passion project created by a BJJ purple belt to help practitioners find training opportunities while traveling.
        
        Our Mission:
        Provide a free, community-driven platform for BJJ enthusiasts to share and discover open mats and gyms worldwide.
        
        Get Involved:
        Report bugs, share feedback, or suggest features at: mfinder.bjj@gmail.com
        
        Thank you for joining the Mat_Finder community!
        Best regards,
        Mat_Finder Team
        """
        return await sendCustomEmail(to: email, subject: subject, content: content)
    }
}
