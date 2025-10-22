//
//  Disclaimer.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//


import SwiftUI


struct DisclaimerView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("Disclaimer Page")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top, 10)
                    
                    Text("Liability Disclaimer")
                        .font(.title)
                        .bold()
                    
                    
                    // Main body text
                    Text("Welcome to Mat_Finder. This page outlines the terms of use and liability disclaimer for the Mat_Finder mobile application.")
                        .font(.body)
                        .padding(.top, 10)
                        .padding(.horizontal)
                    
                    // Group to contain all sections for a consistent layout
                    Group {
                        SectionView(title: "1. User-Generated Content") {
                            Text("Mat_Finder allows users to submit and view information about Brazilian Jiu Jitsu (BJJ) gyms and open mats. While we strive to provide accurate and up-to-date information, we do not guarantee the accuracy, reliability, or completeness of any content submitted by users.")
                        }

                        SectionView(title: "2. No Endorsement") {
                            Text("The inclusion of any gym or open mat on Mat_Finder does not constitute an endorsement by Mat_Finder. Users are encouraged to verify the accuracy of information independently before relying on it.")
                        }

                        SectionView(title: "3. Safety and Legality") {
                            Text("Mat_Finder is designed to help BJJ practitioners find training opportunities. Users are responsible for their own safety and must exercise caution when visiting any gym or open mat listed on Mat_Finder. We do not endorse, support, or promote any illegal or unsafe activities.")
                        }

                        SectionView(title: "4. User Responsibilities") {
                            // Using Markdown for list items is cleaner
                            Text("By using Mat_Finder, you agree to:\n\n- Submit accurate and truthful information.\n- Use the app responsibly and in compliance with applicable laws and regulations.\n- Report any inaccurate or inappropriate content promptly to maintain the integrity of the platform.")
                        }

                        SectionView(title: "5. Limitation of Liability") {
                            Text("Mat_Finder, its developers, and affiliates shall not be held liable for any direct, indirect, incidental, special, or consequential damages arising out of or in any way connected with the use of Mat_Finder or the information contained within it. This includes, but is not limited to, damages for loss of profits, goodwill, use, data, or other intangible losses.")
                        }

                        SectionView(title: "6. Indemnification") {
                            Text("You agree to indemnify and hold harmless Mat_Finder, its developers, and affiliates from any claims, losses, liabilities, damages, costs, or expenses arising out of or in connection with your use of the app or any violation of these terms.")
                        }

                        SectionView(title: "7. Modification of Terms") {
                            Text("Mat_Finder reserves the right to modify these terms at any time without prior notice. Changes will be effective immediately upon posting on this page.")
                        }

                        SectionView(title: "8. Contact Us") {
                            // Using Markdown for the email link is the best practice
                            Text("For inquiries or feedback regarding this disclaimer or any other aspect of Mat_Finder, please contact us at [\(AppConstants.supportEmail)](mailto:\(AppConstants.supportEmail))")
                                .font(.body)
                        }
                    }
                    
                    Text("By using Mat_Finder, you acknowledge that you have read, understood, and agree to be bound by these terms.")
                        .font(.body)
                        .padding(.top, 10)
                        .padding(.horizontal)
                    
                    Text("Last updated: 09/17/2025")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
            // Add a title to the navigation bar
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// SectionView remains the same, as it is a well-designed, reusable component
struct SectionView<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                .padding(.top, 10)
            
            content
                .padding(.horizontal)
        }
    }
}

// Preview remains the same
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
