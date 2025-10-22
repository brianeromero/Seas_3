//  EmailVerificationHandler.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/19/24.
//

import Foundation
import CoreData
import FirebaseAnalytics
import UIKit

class EmailVerificationHandler {
    static func handleEmailVerification(url: URL) async {
        print("Handle Email Verification URL: \(url.absoluteString)")
        Analytics.logEvent("email_verification", parameters: ["url": url.absoluteString])
        
        let context = PersistenceController.shared.container.viewContext
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        do {
            let userInfo = try context.fetch(request)
            if let user = userInfo.first {
                let userName = user.userName
                if let token = components?.queryItems?.first(where: { $0.name == "token" })?.value,
                   let email = components?.queryItems?.first(where: { $0.name == "email" })?.value {
                    
                    let emailManager = UnifiedEmailManager.shared
                    let success = await emailManager.verifyEmail(token: token, email: email, userName: userName)
                    
                    let redirectURL = success ? "http://mfinderbjj.rf.gd/success.html" : "http://mfinderbjj.rf.gd/failed.html"
                    guard let redirectURL = URL(string: redirectURL) else {
                        print("Invalid redirect URL")
                        return
                    }
                    
                    await UIApplication.shared.open(redirectURL, options: [:], completionHandler: nil)
                    print(success ? "Email verification successful" : "Email verification failed")
                } else {
                    print("Token or email missing")
                }
            } else {
                print("User not found")
            }
        } catch {
            print("Error fetching UserInfo: \(error.localizedDescription)")
        }
    }
}
