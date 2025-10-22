//
//  TermsOfService.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/16/24.
//

import Foundation
import SwiftUI


struct ApplicationOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Mat_Finder Application of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                Text("Effective Date: 10/14/2024")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("1. Acceptance of Terms")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    By using Mat_Finder, you agree to these terms. If you do not agree, please do not use the app.
                    """)

                Text("2. Use of the App")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    Mat_Finder is designed to help Brazilian Jiu-Jitsu practitioners find gyms and open mats. You may use the app for personal, non-commercial purposes only.
                    """)

                Text("3. User Responsibilities")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    - Users must provide accurate information when adding or editing gyms and open mats.
                    - Users are responsible for ensuring that their submitted data does not violate any laws or the rights of others.
                    """)

                Text("4. Content Submission")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    When you submit gym or open mat information to Mat_Finder, you grant us a non-exclusive license to use, edit, and display this content within the app. You retain ownership of your content.
                    """)

                Text("5. Location and Personal Data")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    Mat_Finder may use your location to provide nearby results. Location data is not stored permanently. Your personal information is encrypted and stored securely.
                    """)

                Text("6. Passwords and Security")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    Passwords are hashed using secure industry-standard methods and are not stored in plain text. No developer or staff member at Mat_Finder has access to your passwords.
                    """)

                Text("7. Limitation of Liability")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    Mat_Finder is provided "as is," and we make no warranties or representations about its accuracy or functionality. We are not liable for any losses or damages related to the use of the app.
                    """)

                Text("8. Termination")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We reserve the right to terminate your access to Mat_Finder at any time if you violate these terms or for other reasons.
                    """)

                Text("9. Changes to Terms")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We may update these terms at any time. You will be notified of any significant changes via the app.
                    """)

                Text("10. Contact Us")
                    .font(.title2)
                    .fontWeight(.semibold)

                // --- THIS IS THE LINE TO UPDATE ---
                // You can either make it a full Link view or embed it in a Text if the surrounding text is fixed.
                // Given the current structure, let's embed it in a Text view and make only the email clickable.
                // This requires a bit more advanced Text combination or a custom view if you want surrounding text
                // that is not part of the link itself.

                // Option 1: The simplest and most direct way to make only the email a link in this specific context.
                // Replace the entire Text block with this:
                HStack(alignment: .top, spacing: 0) { // Use HStack for inline elements
                    Text("If you have any questions about these terms, contact us at ")
                        .font(.body)
                    Link(AppConstants.supportEmail, destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                        .font(.body)
                        .foregroundColor(.accentColor) // Ensure it looks like a link
                    Text(".") // Add the period back if needed
                        .font(.body)
                }


                Spacer()
            }
            .padding()
        }
        .navigationTitle("Application of Service")
    }
}

struct ApplicationOfServiceView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ApplicationOfServiceView()
                .preferredColorScheme(.light)
            
            ApplicationOfServiceView()
                .preferredColorScheme(.dark)
        }
    }
}
