//
//  PromptForEmailPasswordView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 2/12/25.
//

import SwiftUI
import FirebaseAuth

struct PromptForEmailPasswordView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showingAlert: Bool = false

    let authenticationState = AuthenticationState(hashPassword: HashPassword())

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Submit") {
                let credential = EmailAuthProvider.credential(withEmail: self.email, password: self.password)

                Task {
                    do {
                        try await authenticationState.signInToFirebase(with: credential)
                        print("User authenticated successfully")
                    } catch {
                        print("Authentication error: \(error.localizedDescription)")
                        showingAlert = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Authentication Failed"),
                message: Text("Please check your email and password."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}



#Preview {
    PromptForEmailPasswordView()
}
