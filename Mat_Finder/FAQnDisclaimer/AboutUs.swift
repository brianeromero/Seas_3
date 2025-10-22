//
//  AboutUs.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct AboutUsView: View {
    // Access the current color scheme
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("About Us")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 20)
                
                DisclosureGroup(
                    content: {
                        Text("""
                            If you’re here, you’ve probably explored my app and found your way to this page out of curiosity.
                            """)
                            .font(.body)
                            .padding(.horizontal)
                            .multilineTextAlignment(.leading)
                    },
                    label: {
                        Text("WELCOME TO MAT_FiNDER")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .bold()
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                )
                
                DisclosureGroup(
                    content: {
                        Text("""
                            Mat_Finder is my passion project, developed over the past year with the Brazilian Jiu Jitsu practitioner in mind. Me? I’m a BJJ purple belt with nine years of training out of Orange County, CA. By profession, I work as a Software Implementation Product Owner and Business Analyst. While I usually handle the business side of developing system applications, this is my first attempt at developing an app ex nihilo. Despite my lack of coding experience, my frequent work travels and years of training led me to develop this app out of both need and curiosity. I often wondered if there was a gym near my hotel with an open mat and whether I should pack my Gi or NoGi garb. Too often, I found myself in places with no BJJ gym relatively close by or having my search findings return vague “grappling” options at the “Martial Arts” dojo down the street. This led me to create Mat_F_inder.
                            """)
                            .font(.body)
                            .padding(.horizontal)
                            .multilineTextAlignment(.leading)
                    },
                    label: {
                        Text("WHO ARE YOU? WHAT IS THIS APP?")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .bold()
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                )
                
                DisclosureGroup(
                    content: {
                        Text("""
                            You are a BJJ practitioner who loves training and traveling. You enjoy attending different open mats, or you love your gym and want to see your open mats expand beyond the same 5-10 regulars. You are being asked to pilot this app: add gyms, add open mat times, and overall, help test Mat_Finder for user experience (UX). Your feedback on bugs and any related issues is crucial.
                            """)
                            .font(.body)
                            .padding(.horizontal)
                            .multilineTextAlignment(.leading)
                    },
                    label: {
                        Text("MORE IMPORTANTLY... WHO ARE YOU?")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .bold()
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                )
                
                DisclosureGroup(
                    content: {
                        Text("""
                            The answer is no. Currently, and I hope to change this, there is no existing API database I can link up to gather this data. If there were, the app would have been either easier to build or probably unnecessary. BJJ gyms often change their open mat schedules on a whim. What might be a Saturday at 9am could change for the summer to Sunday at 10am, or a new open mat might be added. If it were easy to scrub the data, we wouldn’t need this app. Thus, I rely on the BJJ community to enter their gym’s open mats, or any open mats they know of in the area. Using your current location or the area you are visiting, you can enter an address or postal code to find an open mat near you.
                            """)
                            .font(.body)
                            .padding(.horizontal)
                            .multilineTextAlignment(.leading)
                    },
                    label: {
                        Text("WHY DO I HAVE TO ENTER GYM/OPEN MAT INFO? CAN’T YALL SCRUB THE INTERNET FOR THIS?")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .bold()
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                )
                
                DisclosureGroup(
                    content: {
                        Text("""
                            For now, I am going live with this app for iOS. Sorry - no Android yet. I’m still a white belt at coding and went with what I know and have.
                            """)
                            .font(.body)
                            .padding(.horizontal)
                            .multilineTextAlignment(.leading)
                    },
                    label: {
                        Text("WHY ONLY iOS? GOT SOMETHING AGAINST ANDROID?")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .bold()
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                )
                
                DisclosureGroup(
                    content: {
                        Text("""
                            For now, the app is completely free and ad-free. Currently, it’s a service I want to offer to the BJJ community. Eventually, the app will have ads and other monetization features (it would be nice to be compensated for my effort, and hosting an app or related data on the app stores isn’t free for me).

                            Thank you for reading this.
                            Mat_Finder
                            """)
                            .font(.body)
                            .padding(.horizontal)
                            .multilineTextAlignment(.leading) // Align text left
                    },
                    label: {
                        Text("FREE BUT...NOT AD-FREE...YET")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .bold()
                            .padding(.top, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                )
                
                Divider()
                
                Text("Contact Us")
                    .font(.title)
                    .bold()
                    .padding(.top, 30)
                
                Text("To report bugs or for inquiries or feedback, please reach out to us at:")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
                
                // --- THIS IS THE LINE TO UPDATE ---
                Link(AppConstants.supportEmail, destination: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                    .font(.body)
                    .padding(.horizontal)
            }
            .padding(.horizontal)
        }
        // If AboutUsView is pushed onto a NavigationStack, the title should be set there.
        // If it's a root view, you might apply a .navigationTitle
        // .navigationTitle("About Us")
    }
}

struct AboutUsView_Previews: PreviewProvider {
    static var previews: some View {
        AboutUsView()
    }
}
