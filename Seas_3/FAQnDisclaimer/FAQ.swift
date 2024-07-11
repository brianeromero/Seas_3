//
//  FAQ.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct FAQView: View {
    var faqItems: [FAQItem] = [
        FAQItem(question: "What is MF_inder (Mat_Finder)?",
                answer: "MF_inder is a mobile application designed for Brazilian Jiu Jitsu (BJJ) practitioners to find gyms and open mat opportunities near their location or any specified area."),
        FAQItem(question: "How does MF_inder work?",
                answer: "Users can search for BJJ gyms and open mats based on their current location or specified area. They can also add new gyms or open mat information to the app."),
        FAQItem(question: "Is MF_inder free to use?",
                answer: "Yes, MF_inder is currently free to use without any advertisements."),
        FAQItem(question: "Is my personal information secure on MF_inder?",
                answer: "We take user privacy seriously. Your personal information is encrypted and stored securely. We do not share your information with third parties without your consent."),
        FAQItem(question: "How can I add a new gym or open mat to MF_inder?",
                answer: "You can add new gyms or open mats by navigating to the 'Add Location' option in the app menu and providing accurate details about the location and schedule."),
        FAQItem(question: "Can I edit or delete information I've submitted?",
                answer: "Yes, you can edit or delete information you've submitted by accessing the 'Manage Locations' section in the app."),
        FAQItem(question: "Why do you need my location information?",
                answer: "MF_inder uses your location to provide accurate results for nearby BJJ gyms and open mats. Your location data is not stored permanently."),
        FAQItem(question: "How often is the information on MF_inder updated?",
                answer: "We encourage users to update information regularly. New submissions and edits are processed promptly."),
        FAQItem(question: "Is MF_inder available on Android?",
                answer: "Currently, MF_inder is available only on iOS. We are working on an Android version."),
        FAQItem(question: "How can I report inaccurate information or issues with the app?",
                answer: "Please report any issues or inaccuracies by contacting our support team at mfinder.bjj@gmail.com."),
        FAQItem(question: "Will MF_inder have advertisements in the future?",
                answer: "While MF_inder is currently ad-free, we may introduce advertisements in the future to support the app's development and maintenance costs."),
        FAQItem(question: "How can I contact support if I have more questions?",
                answer: "For further assistance or questions, please email us at mfinder.bjj@gmail.com. We are here to help!")
    ]
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("FAQ")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 10)
                
                ForEach(faqItems.indices, id: \.self) { index in
                    FAQItemView(item: faqItems[index])
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FAQItemView: View {
    var item: FAQItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.question)
                .font(.headline)
            
            Text(item.answer)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 5)
    }
}

struct FAQItem {
    var question: String
    var answer: String
}

struct FAQView_Previews: PreviewProvider {
    static var previews: some View {
        FAQView()
    }
}
