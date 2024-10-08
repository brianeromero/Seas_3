//
//  SignIn.swift
//  Seas_3
//
//  Created by Brian Romero on 10/8/24.
//

import SwiftUI
import CoreData

struct SignInView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authenticationState: AuthenticationState
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""
    @State private var passwordAttempts: Int = 0
    @State private var isAccountLocked: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Sign In")
                .font(.largeTitle)

            TextField("Email address", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: {
                self.signIn()
            }) {
                Text("Sign In")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            if isAccountLocked {
                Text("Account locked due to excessive password attempts.")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .navigationTitle("Sign In")
    }

    private func signIn() {
        // Check if email exists
        if let user = fetchUserByEmail(email) {
            // Check password
            if verifyPassword(password, againstHash: user.passwordHash!) {
                // Login successful
                authenticationState.isAuthenticated = true
                authenticationState.user = user
            } else {
                // Password incorrect
                passwordAttempts += 1
                if passwordAttempts >= 5 {
                    isAccountLocked = true
                }
                errorMessage = "Invalid password. Attempts remaining: \(5 - passwordAttempts)"
            }
        } else {
            // Email does not exist
            errorMessage = "Email not found. Please create an account."
            // Navigate to Account Creation Form
            // ...
        }
    }

    func fetchUserByEmail(_ email: String) -> UserInfo? {
        let request = UserInfo.fetchRequest() as NSFetchRequest<UserInfo>
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let users = try viewContext.fetch(request)
            return users.first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
}



// SignIn.swift (add the following code)

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SignInView()
                .environmentObject(AuthenticationState())
        }
    }
}
