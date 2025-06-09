//
//  FAQnDisclaimerMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import os // <--- Add this line for os_log

// Define the logger for this file, or if you have a centralized logger file,
// ensure it's imported here and use the logger defined there.
// Assuming IslandMenulogger is not shared via a module, re-define it or
// create a specific logger for FAQnDisclaimerMenu.
// For now, let's assume you want to use the same logger.


let FAQnDisclaimerLogger = OSLog(subsystem: "Seas3.Subsystem", category: "FAQnDisclaimer")
// Add other loggers here as needed

class FAQnDisclaimerMenu: ObservableObject {
    enum MenuItem {
        case whoWeAre
        case disclaimer
        case faq
    }
    
    @Published var selectedItem: MenuItem? = nil
    
    var contentView: some View {
        switch selectedItem {
        case .whoWeAre:
            return AnyView(WhoWeAreView())
        case .disclaimer:
            return AnyView(DisclaimerView())
        case .faq:
            return AnyView(FAQView())
        case .none:
            return AnyView(EmptyView())
        }
    }
}

struct FAQnDisclaimerMenuView: View {
    @ObservedObject var menu = FAQnDisclaimerMenu()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                List {
                    NavigationLink(
                        destination: WhoWeAreView()
                            .onAppear { os_log("WhoWeAreView Appeared", log: IslandMenulogger) },
                        tag: .whoWeAre,
                        selection: $menu.selectedItem
                    ) {
                        HStack {
                            Image("MF_little")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .padding(.trailing, 10)
                            Text("Who We Are")
                                .padding(.leading, 10)
                        }
                    }
                    
                    NavigationLink(
                        destination: DisclaimerView()
                            .onAppear { os_log("DisclaimerView Appeared", log: IslandMenulogger) },
                        tag: .disclaimer,
                        selection: $menu.selectedItem
                    ) {
                        HStack {
                            Image("disclaimer_logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .padding(.trailing, 10)
                            Text("Disclaimer")
                                .padding(.leading, 10)
                        }
                    }
                    
                    NavigationLink(
                        destination: FAQView()
                            .onAppear { os_log("FAQView Appeared", log: IslandMenulogger) },
                        tag: .faq,
                        selection: $menu.selectedItem
                    ) {
                        HStack {
                            Image("faq")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .padding(.trailing, 10)
                            Text("FAQ")
                                .padding(.leading, 10)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                menu.contentView
                    .padding(.horizontal)
            }
            .padding(.horizontal)
            .navigationTitle("FAQ & Disclaimer")
        }
    }
}



struct FAQnDisclaimerMenuView_Previews: PreviewProvider {
    static var previews: some View {
        FAQnDisclaimerMenuView()
    }
}
