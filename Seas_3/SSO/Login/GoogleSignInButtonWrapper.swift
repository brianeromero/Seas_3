//
//  GoogleSignInButtonWrapper.swift
//  Seas_3
//
//  Created by Brian Romero on 10/7/24.
//


import Foundation
import SwiftUI
import GoogleSignIn
import CoreData

struct GoogleSignInButtonWrapper: UIViewRepresentable {
    @EnvironmentObject var authenticationState: AuthenticationState
    var handleError: (String) -> Void
    let googleClientID: String?
    let managedObjectContext: NSManagedObjectContext  // Pass managedObjectContext here

    func makeUIView(context: Context) -> GIDSignInButton {
        print("Making Google Sign-In button")
        let button = GIDSignInButton()
        button.frame.size = CGSize(width: ButtonStyle.width, height: ButtonStyle.height)
        button.addTarget(context.coordinator, action: #selector(context.coordinator.signIn), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {
        print("Updating Google Sign-In button")
    }

    func makeCoordinator() -> Coordinator {
        print("Creating coordinator for Google Sign-In button")
        return Coordinator(self)
    }

    func fetchGoogleUserProfile(managedObjectContext: NSManagedObjectContext, authenticationState: AuthenticationState) {
        print("Fetching Google user profile")
        
        // Check if current user is signed in
        guard let currentUser = GIDSignIn.sharedInstance.currentUser,
              let userProfile = currentUser.profile else {
            print("No current Google user")
            return
        }

        // Log user data for debugging (consider removing in production)
        print("Google Sign-In Current User: \(currentUser)")
        print("Google Sign-In User Profile: \(userProfile)")
        
        // Safely extract user info
        let userId = currentUser.userID ?? "Unknown" // Provide default value if nil
        let userName = userProfile.name
        let userEmail = userProfile.email
        
        print("User Info: \(userId), \(userName), \(userEmail)")
        
        // Create or update UserInfo entity
        let fetchRequest: NSFetchRequest<UserInfo> = UserInfo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", userEmail)
        
        DispatchQueue.main.async {
            do {
                print("Fetching existing user data")
                // Fetch existing user data
                let users = try managedObjectContext.fetch(fetchRequest)
                var userInfo: UserInfo
                
                // Update existing user or create new one
                if let existingUser = users.first {
                    print("Updating existing user")
                    userInfo = existingUser
                } else {
                    print("Creating new user")
                    userInfo = UserInfo(context: managedObjectContext)
                }
                
                // Update user info
                userInfo.email = userEmail
                userInfo.name = userName
                userInfo.userName = userName
                userInfo.userID = userId  // Handle user ID safely
                
                print("Saving changes to managed object context")
                // Save changes to managed object context
                try managedObjectContext.save()
            } catch let error as NSError {
                print("Error fetching or saving user: \(error.localizedDescription), \(error.userInfo)")
            }
        }
        
        // Use the passed authenticationState instead of singleton
        do {
            print("Updating AuthenticationState with Google user data")
            try authenticationState.updateSocialUser(
                .google, // Correct use of the SocialPlatform enum
                userId,
                userName,
                userEmail
            )
        } catch {
            print("Error updating AuthenticationState: \(error.localizedDescription)")
        }
    }

    class Coordinator: NSObject {
        var parent: GoogleSignInButtonWrapper?
        let googleClientID: String
        let googleScopes: [String] = ["openid", "email", "profile"]

        init(_ parent: GoogleSignInButtonWrapper) {
            self.parent = parent
            self.googleClientID = parent.googleClientID ?? ""
            super.init()
        }

        @objc func signIn() {
            print("Google Sign-In initiated")

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("No root view controller available")
                return
            }

            let config = GIDConfiguration(clientID: googleClientID)
            print("GIDConfiguration: \(config)")

            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController, hint: nil, additionalScopes: googleScopes) { [weak self] result, error in
                guard let self = self else { return }
                
                // Error handling for Google Sign-In
                if let error = error {
                    print("Google Sign-In error: \(error.localizedDescription)")
                    self.parent?.handleError(error.localizedDescription)
                    return
                }

                print("Google Sign-In successful")
                if let user = result?.user {
                    let userID = user.userID ?? ""
                    let userName = user.profile?.name ?? ""
                    let userEmail = user.profile?.email ?? ""

                    print("Google Sign-In User ID: \(userID)")
                    print("Google Sign-In User Name: \(userName)")
                    print("Google Sign-In User Email: \(userEmail)")

                    // Update AuthenticationState with Google user data
                    do {
                        try self.parent?.authenticationState.updateSocialUser(.google, userID, userName, userEmail)
                    } catch {
                        print("Error updating AuthenticationState: \(error.localizedDescription)")
                    }

                    // Call fetchGoogleUserProfile to update Core Data
                    self.parent?.fetchGoogleUserProfile(managedObjectContext: self.parent?.managedObjectContext ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType), authenticationState: self.parent?.authenticationState ?? AuthenticationState())
                }
            }
        }
    }
}

struct GoogleSignInButtonWrapper_Previews: PreviewProvider {
    @StateObject static var authenticationState = AuthenticationState()

    static var previews: some View {
        GoogleSignInButtonWrapper(
            handleError: { message in
                print("Error: \(message)")
            },
            googleClientID: AppConfig.shared.googleClientID,
            managedObjectContext: PersistenceController.shared.container.viewContext // Pass a valid context here
        )
        .environmentObject(authenticationState)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

