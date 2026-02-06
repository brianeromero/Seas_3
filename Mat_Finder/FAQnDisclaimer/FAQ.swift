//
//  FAQ.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct FAQItem: Identifiable {
    let id = UUID()
    var question: String
    var answer: String
}

struct FAQView: View {
    var faqItems: [FAQItem] = [
        FAQItem(question: "What is Mat_Finder?",
                answer: "Mat_Finder is a mobile application designed for Brazilian Jiu Jitsu (BJJ) practitioners to find gyms and open mat opportunities near their location or any specified area."),
        FAQItem(question: "How does Mat_Finder work?",
                answer: "Users can search for BJJ gyms and open mats based on their current location or specified area. They can also add new gyms or open mat information to the app."),
        FAQItem(question: "Is Mat_Finder free to use?",
                answer: "Yes, Mat_Finder is free to use. I’m experimenting with a small amount of advertising — such as simple banner ads at the bottom of the app — to help cover ongoing costs like database hosting and yearly maintenance. The goal isn’t profit, just keeping the app sustainable for the BJJ community without paywalls or subscriptions."),
        FAQItem(question: "Is my personal information secure on Mat_Finder?",
                answer: "We take user privacy seriously. Your personal information is encrypted and stored securely. We do not share your information with third parties without your consent."),
        FAQItem(question: "How can I add a new gym or open mat to Mat_Finder?",
                answer: "You can add new gyms or open mats by navigating to the 'Add Location' option in the app menu and providing accurate details about the location and schedule."),
        FAQItem(question: "Can I edit or delete information I've submitted?",
                answer: "Yes, you can edit or delete information you've submitted by accessing the 'Manage Locations' section in the app."),
        FAQItem(question: "Why do you need my location information?",
                answer: "Mat_Finder uses your location to provide accurate results for nearby BJJ gyms and open mats. Your location data is not stored permanently."),
        FAQItem(question: "How often is the information on Mat_Finder updated?",
                answer: "We encourage users to update information regularly. New submissions and edits are processed promptly."),
        FAQItem(question: "Is Mat_Finder available on Android?",
                answer: "Currently, Mat_Finder is available only on iOS. We are working on an Android version."),
        FAQItem(question: "How can I report inaccurate information or issues with the app?",
                answer: "Please report any issues or inaccuracies by contacting our support team at **EMAIL_LINK**."),
        FAQItem(question: "How can I contact support if I have more questions?",
                answer: "For further assistance or questions, please email us at **EMAIL_LINK**. We are here to help!")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    ForEach(faqItems) { item in
                        DisclosureGroup(
                            content: {
                                VStack(alignment: .leading) {
                                    if item.answer.contains("**EMAIL_LINK**") {
                                        let parts = item.answer.components(separatedBy: "**EMAIL_LINK**")
                                        Text(parts[0])
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                        
                                        Link(AppConstants.supportEmail,
                                             destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                                            .font(.body)
                                            .foregroundColor(.accentColor)
                                        
                                        if parts.count > 1 && !parts[1].isEmpty {
                                            Text(parts[1])
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                    } else {
                                        Text(item.answer)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .padding(.horizontal)
                            },
                            label: {
                                Text(item.question)
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        )
                        .padding(.vertical, 5)
                    }
                    
                    Divider()
                        .padding(.vertical, 10)
                    
                    Text("Contact Us")
                        .font(.title)
                        .bold()
                        .foregroundColor(.primary)
                        .padding(.top, 10)
                    
                    Text("To report bugs or for inquiries or feedback, please reach out to us at:")
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Link(AppConstants.supportEmail,
                         destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                        .font(.body)
                        .foregroundColor(.accentColor)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal)
                .background(Color(uiColor: .systemBackground))
                .ignoresSafeArea()
            }
            .navigationTitle("FAQ")
        }
    }
}
