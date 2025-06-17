//
//  Disclaimer.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import SwiftUI


struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Disclaimer Page")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 10)
                
                Text("Liability Disclaimer")
                    .font(.title)
                    .bold()
                
                Text("Welcome to MF_inder (Mat_Finder). This page outlines the terms of use and liability disclaimer for the MF_inder mobile application.")
                    .font(.body)
                    .padding(.horizontal)

                Group {
                    SectionView(title: "1. User-Generated Content",
                                content: "MF_inder allows users to submit and view information about Brazilian Jiu Jitsu (BJJ) gyms and open mats. While we strive to provide accurate and up-to-date information, we do not guarantee the accuracy, reliability, or completeness of any content submitted by users.")
                    
                    SectionView(title: "2. No Endorsement",
                                content: "The inclusion of any gym or open mat on MF_inder does not constitute an endorsement by MF_inder. Users are encouraged to verify the accuracy of information independently before relying on it.")
                    
                    SectionView(title: "3. Safety and Legality",
                                content: "MF_inder is designed to help BJJ practitioners find training opportunities. Users are responsible for their own safety and must exercise caution when visiting any gym or open mat listed on MF_inder. We do not endorse, support, or promote any illegal or unsafe activities.")
                    
                    SectionView(title: "4. User Responsibilities",
                                content: "By using MF_inder, you agree to:\n\n- Submit accurate and truthful information.\n- Use the app responsibly and in compliance with applicable laws and regulations.\n- Report any inaccurate or inappropriate content promptly to maintain the integrity of the platform.")
                    
                    SectionView(title: "5. Limitation of Liability",
                                content: "MF_inder, its developers, and affiliates shall not be held liable for any direct, indirect, incidental, special, or consequential damages arising out of or in any way connected with the use of MF_inder or the information contained within it. This includes, but is not limited to, damages for loss of profits, goodwill, use, data, or other intangible losses.")
                    
                    SectionView(title: "6. Indemnification",
                                content: "You agree to indemnify and hold harmless MF_inder, its developers, and affiliates from any claims, losses, liabilities, damages, costs, or expenses arising out of or in connection with your use of the app or any violation of these terms.")
                    
                    SectionView(title: "7. Modification of Terms",
                                content: "MF_inder reserves the right to modify these terms at any time without prior notice. Changes will be effective immediately upon posting on this page.")
                    
                    // --- UPDATED Section 8. Contact Us ---
                    // Option 1: Modify SectionView to accept a ViewBuilder for content
                    // (This is the most flexible long-term solution for reusable components)
                    
                    // For now, let's keep SectionView as is (String content) and handle the link here.
                    // This means duplicating the title formatting from SectionView.
                    
                    Text("8. Contact Us") // This replicates the title styling from SectionView
                        .font(.headline)
                        .padding(.top, 10)
                    
                    HStack(alignment: .top, spacing: 0) { // Using HStack for inline text + link
                        Text("For inquiries or feedback regarding this disclaimer or any other aspect of MF_inder, please contact us at ")
                            .font(.body)
                        Link(AppConstants.supportEmail, destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                            .font(.body)
                            .foregroundColor(.accentColor) // Make it look like a link
                        Text(".")
                            .font(.body)
                    }
                    .padding(.horizontal) // Apply padding to the entire HStack
                }
                
                Text("By using MF_inder, you acknowledge that you have read, understood, and agree to be bound by these terms.")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
                
                Text("Last updated: 06/18/2024")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.horizontal)
        }
    }
}

struct SectionView: View {
    var title: String
    var content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .padding(.top, 10)
            
            Text(content)
                .font(.body)
                .padding(.horizontal)
        }
    }
}

struct DisclaimerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DisclaimerView()
                .preferredColorScheme(.light)
            
            DisclaimerView()
                .preferredColorScheme(.dark)
        }
    }
}
