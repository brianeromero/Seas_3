//
//  PrivacyPolicy.swift
//  Seas_3
//
//  Created by Brian Romero on 10/16/24.
//

import Foundation
import SwiftUI


struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Mat_Finder Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                Text("Effective Date: 10/14/2024")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Text("Introduction")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("""
                    Mat_Finder ("we," "us," or "our") is committed to protecting the privacy of our users ("you" or "your"). This Privacy Policy explains what information we collect, how we use it, and under what circumstances we may disclose it.
                    """)
                    .padding(.bottom, 10)
                
                Text("Information We Collect")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We collect two types of information from users:
                    - **Personal Information:** This includes information that can identify you directly, such as your location (if you choose to share it) and your email address.
                    - **Non-Personal Information:** This includes technical data like device type, operating system, and usage data such as search queries within the app.
                    """)
                
                Text("How We Use Your Information")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We use your information for the following purposes:
                    - **To provide and improve Mat_Finder:** We may use your location (if shared) to show nearby BJJ gyms and open mats. Your email may be used for communication purposes.
                    - **To personalize your experience:** We may tailor your search results based on your location history (if enabled).
                    - **To send important information:** Your email address may be used to send service updates or security notices.
                    """)
                
                Text("Sharing Your Information")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We do not share personal information with third parties without your consent, except for non-personal information shared with service providers to help us operate Mat_Finder. We may disclose information if required by law or to protect the rights of others.
                    """)
                
                Text("Data Retention")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We retain your information as long as needed to fulfill the purposes outlined in this Privacy Policy, after which it will be deleted or anonymized.
                    """)
                
                Text("Security")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We take reasonable steps to protect your information from unauthorized access, disclosure, alteration, or destruction. Passwords are securely hashed using industry-standard methods and are not stored in plain text. We do not store or retain plain-text passwords, and they are not visible to any developer or anyone at Mat_Finder. However, no internet transmission or electronic storage is completely secure.
                    """)
                
                Text("Your Choices")
                    .font(.title2)
                    .fontWeight(.semibold)

                // --- CORRECTED SECTION FOR "Your Choices" ---
                // Using an HStack to combine static text with a Link
                VStack(alignment: .leading) { // Keep leading alignment for the entire block
                    Text("- **Location Sharing:** You can enable or disable location sharing in your device settings.")
                        .font(.body)
                    
                    HStack(alignment: .top, spacing: 0) { // Use HStack for the "Contacting Us" line
                        Text("- **Contacting Us:** You may request to delete your information by emailing us at ")
                            .font(.body)
                        Link(AppConstants.supportEmail, destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                            .font(.body)
                            .foregroundColor(.accentColor)
                        Text(".")
                            .font(.body)
                    }
                }
                .padding(.bottom, 10) // Add some padding after this section if needed
                
                Text("Children's Privacy")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    Mat_Finder is not intended for children under 13. If you believe your child has provided us with personal information, please contact us and we will delete it.
                    """)
                
                Text("Changes to this Privacy Policy")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("""
                    We may update this policy and will notify you by posting the changes on this page.
                    """)
                
                Text("Contact Us")
                    .font(.title2)
                    .fontWeight(.semibold)

                // This section was already correctly updated in the previous turn, keeping it.
                HStack(alignment: .top, spacing: 0) {
                    Text("For any questions, please contact us at ")
                        .font(.body)
                    Link(AppConstants.supportEmail, destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                        .font(.body)
                        .foregroundColor(.accentColor)
                    Text(".")
                        .font(.body)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
    }
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}
