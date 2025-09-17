//// DoNotStorePasswords.swift
// Seas_3
//
// Created by Brian Romero on 10/8/24.
//

import SwiftUI

struct DoNotStorePasswords: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Mat_Finder does not store passwords.")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("For more information, please refer to our privacy policy.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()

            // You can add more content or a link to your policy here
            Text("Privacy Policy")
                .font(.footnote)
                .foregroundColor(.blue)
                .underline()
                .onTapGesture {
                    // Open the privacy policy link if applicable
                    // This could use a link opener, e.g. using UIApplication.shared.open(URL(string: "https://your-privacy-policy-url.com")!)
                }
        }
        .padding()
        .navigationTitle("Password Policy")
    }
}

struct DoNotStorePasswords_Previews: PreviewProvider {
    static var previews: some View {
        DoNotStorePasswords()
    }
}
