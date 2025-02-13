//
//  PromptForEmailPasswordView.swift
//  Seas_3
//
//  Created by Brian Romero on 2/12/25.
//

import SwiftUI
import FirebaseAuth

struct PromptForEmailPasswordView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingAlert: Bool = false
    
    let authenticationManager = AuthenticationManager()
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Submit") {
                print("Submit button tapped")
                self.authenticationManager.log(message: "Submit button tapped", level: .info)
                
                DispatchQueue.main.async {
                    print("DispatchQueue main async called")
                    self.authenticationManager.promptForEmailPassword(email: self.email) { password in
                        print("promptForEmailPassword completion handler called")
                        // Handle password entry
                        print("Password entered: \(password)")
                        
                        // Call handleAuthentication here
                        let credential = EmailAuthProvider.credential(withEmail: self.email, password: password)
                        self.authenticationManager.handleAuthentication(with: credential) { result in
                            switch result {
                            case .success(let user):
                                print("User authenticated successfully: \(user)")
                            case .failure(let error):
                                print("Authentication error: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PromptForEmailPasswordView()
}
